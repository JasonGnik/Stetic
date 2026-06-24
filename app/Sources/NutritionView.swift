import SwiftUI
import PhotosUI

// Daily nutrition: totals vs target, today's meals, and photo meal-scanning.
struct NutritionView: View {
    let target: PlanContent.Macros?

    @State private var meals: [MealLog] = []
    @State private var pickerItem: PhotosPickerItem?
    @State private var scanning = false
    @State private var estimate: MealEstimate?
    @State private var errorMsg: String?

    private var cals: Double { meals.reduce(0) { $0 + $1.calories } }
    private var protein: Double { meals.reduce(0) { $0 + $1.protein_g } }
    private var carbs: Double { meals.reduce(0) { $0 + $1.carbs_g } }
    private var fat: Double { meals.reduce(0) { $0 + $1.fat_g } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Food").font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.txt)
                summaryCard
                scanButton
                if let errorMsg {
                    Text(errorMsg).font(.system(size: 12)).foregroundStyle(Theme.red)
                }
                if meals.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) { ForEach(meals) { mealRow($0) } }
                }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
        }
        .background(Theme.bg.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .task { await reload() }
        .onChange(of: pickerItem) { _, v in Task { await runScan(v) } }
        .sheet(item: $estimate) { est in confirmSheet(est) }
    }

    private var summaryCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(cals))").font(.system(size: 34, weight: .heavy)).foregroundStyle(Theme.txt)
                if let t = target {
                    Text("/ \(Int(t.calories)) cal").font(.system(size: 15)).foregroundStyle(Theme.mut)
                    Spacer()
                    Text("\(max(0, Int(t.calories - cals))) left").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.acc)
                }
            }
            if let t = target {
                ProgressBar(value: cals, total: t.calories, tint: Theme.acc)
                HStack(spacing: 10) {
                    macroBar("Protein", protein, t.protein_g, Theme.acc)
                    macroBar("Carbs", carbs, t.carbs_g, Color(hex: 0x49B6FF))
                    macroBar("Fat", fat, t.fat_g, Color(hex: 0xFF6B4A))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
    }

    private func macroBar(_ label: String, _ v: Double, _ t: Double, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.mut)
            ProgressBar(value: v, total: t, tint: c)
            Text("\(Int(v)) / \(Int(t))g").font(.system(size: 10)).foregroundStyle(Theme.mut)
        }
        .frame(maxWidth: .infinity)
    }

    private var scanButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            HStack(spacing: 10) {
                if scanning { ProgressView().tint(Color(hex: 0x0E0E10)) }
                else { Image(systemName: "camera.fill").font(.system(size: 15, weight: .bold)) }
                Text(scanning ? "Reading your meal…" : "Scan a meal").font(.system(size: 15, weight: .bold))
            }
            .frame(maxWidth: .infinity).padding(14)
            .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
            .foregroundStyle(Color(hex: 0x0E0E10))
        }
        .disabled(scanning)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife").font(.system(size: 26)).foregroundStyle(Theme.mut)
            Text("No meals logged today").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
            Text("Snap a photo and we'll estimate the calories.").font(.system(size: 12)).foregroundStyle(Theme.mut)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30)
    }

    private func mealRow(_ m: MealLog) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(m.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                Text("P \(Int(m.protein_g)) · C \(Int(m.carbs_g)) · F \(Int(m.fat_g))")
                    .font(.system(size: 11)).foregroundStyle(Theme.mut)
            }
            Spacer()
            Text("\(Int(m.calories)) cal").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
            Button { Task { await delete(m) } } label: {
                Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
    }

    private func confirmSheet(_ est: MealEstimate) -> some View {
        VStack(spacing: 16) {
            Capsule().fill(Theme.line).frame(width: 38, height: 5).padding(.top, 10)
            Text("Add this meal?").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
            VStack(spacing: 6) {
                Text(est.name).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt).multilineTextAlignment(.center)
                Text("\(Int(est.calories)) cal · P \(Int(est.protein_g)) · C \(Int(est.carbs_g)) · F \(Int(est.fat_g))")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut)
                Text("Confidence: \(est.confidence)\(est.note.map { $0.isEmpty ? "" : " · \($0)" } ?? "")")
                    .font(.system(size: 11)).foregroundStyle(Theme.mut).multilineTextAlignment(.center)
            }
            .padding(16).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
            HStack(spacing: 10) {
                Button { estimate = nil } label: {
                    Text("Discard").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card)).foregroundStyle(Theme.txt)
                }
                Button { Task { await save(est) } } label: {
                    Text("Add to today").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.acc)).foregroundStyle(Color(hex: 0x0E0E10))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.height(320)])
    }

    // MARK: actions
    private func reload() async { meals = (try? await ScanAPI.shared.meals(on: LogDate.today)) ?? [] }

    private func runScan(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        errorMsg = nil; scanning = true
        defer { scanning = false; pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { errorMsg = "Couldn't read that photo."; return }
        let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.8) ?? data
        do {
            estimate = try await ScanAPI.shared.scanMeal(.init(mimeType: "image/jpeg", dataB64: jpeg.base64EncodedString()))
        } catch { errorMsg = "Scan failed — try a clearer photo." }
    }

    private func save(_ est: MealEstimate) async {
        try? await ScanAPI.shared.logMeal(est)
        estimate = nil
        await reload()
    }

    private func delete(_ m: MealLog) async {
        guard let id = m.id else { return }
        try? await ScanAPI.shared.deleteMeal(id: id)
        await reload()
    }
}
