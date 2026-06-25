import SwiftUI
import PhotosUI

// Daily nutrition: totals vs target, today's meals, and photo meal-scanning.
struct NutritionView: View {
    let target: PlanContent.Macros?

    @State private var meals: [MealLog] = []
    @State private var pickerItem: PhotosPickerItem?
    @State private var scanImage: UIImage?
    @State private var scanB64: String?
    @State private var showScan = false
    @State private var errorMsg: String?
    @State private var showManual = false
    @State private var mName = ""
    @State private var mCals = ""
    @State private var mProtein = ""
    @State private var mCarbs = ""
    @State private var mFat = ""

    // Quick-add presets for when someone doesn't want to scan.
    private let suggestions: [MealEstimate] = [
        .init(name: "Chicken, rice & veg", calories: 600, protein_g: 50, carbs_g: 62, fat_g: 14, confidence: "preset"),
        .init(name: "Protein shake", calories: 200, protein_g: 40, carbs_g: 6, fat_g: 2, confidence: "preset"),
        .init(name: "Greek yogurt & berries", calories: 240, protein_g: 22, carbs_g: 28, fat_g: 4, confidence: "preset"),
        .init(name: "Eggs & toast", calories: 350, protein_g: 22, carbs_g: 30, fat_g: 16, confidence: "preset"),
        .init(name: "Steak & potatoes", calories: 700, protein_g: 55, carbs_g: 50, fat_g: 28, confidence: "preset"),
        .init(name: "Oats & banana", calories: 400, protein_g: 14, carbs_g: 72, fat_g: 9, confidence: "preset"),
    ]

    private var cals: Double { meals.reduce(0) { $0 + $1.calories } }
    private var protein: Double { meals.reduce(0) { $0 + $1.protein_g } }
    private var carbs: Double { meals.reduce(0) { $0 + $1.carbs_g } }
    private var fat: Double { meals.reduce(0) { $0 + $1.fat_g } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Food").font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.txt)
                summaryCard
                actionRow
                if let errorMsg {
                    Text(errorMsg).font(.system(size: 12)).foregroundStyle(Theme.red)
                }
                suggestionsSection
                if meals.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TODAY'S MEALS").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
                        ForEach(meals) { mealRow($0) }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
        }
        .background(Theme.bg.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .task { await reload() }
        .onChange(of: pickerItem) { _, v in Task { await loadPhoto(v) } }
        .sheet(isPresented: $showManual) { manualSheet }
        .fullScreenCover(isPresented: $showScan) {
            if let img = scanImage, let b64 = scanB64 {
                MealScanView(image: img, dataB64: b64, onLogged: { Task { await reload() } })
            }
        }
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

    private var actionRow: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill").font(.system(size: 15, weight: .bold))
                    Text("Scan a meal").font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity).padding(14)
                .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
                .foregroundStyle(Color(hex: 0x0E0E10))
            }
            Button { showManual = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil").font(.system(size: 15, weight: .bold))
                    Text("Add").font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity).padding(14)
                .background(RoundedRectangle(cornerRadius: 13).fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.line, lineWidth: 1)))
                .foregroundStyle(Theme.txt)
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK ADD").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions) { s in
                        Button { Task { await save(s) } } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(s.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                                Text("\(Int(s.calories)) cal · \(Int(s.protein_g))P").font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card)
                                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
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

    private var manualSheet: some View {
        VStack(spacing: 14) {
            Capsule().fill(Theme.line).frame(width: 38, height: 5).padding(.top, 10)
            Text("Add a meal").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
            TextField("", text: $mName, prompt: Text("Meal name").foregroundStyle(Theme.mut))
                .font(.system(size: 16)).foregroundStyle(Theme.txt).padding(13)
                .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))
            HStack(spacing: 8) {
                manualField("Calories", $mCals)
                manualField("Protein", $mProtein)
            }
            HStack(spacing: 8) {
                manualField("Carbs", $mCarbs)
                manualField("Fat", $mFat)
            }
            Button {
                let est = MealEstimate(name: mName.isEmpty ? "Meal" : mName,
                    calories: Double(mCals) ?? 0, protein_g: Double(mProtein) ?? 0,
                    carbs_g: Double(mCarbs) ?? 0, fat_g: Double(mFat) ?? 0, confidence: "manual")
                Task { showManual = false; await save(est); mName = ""; mCals = ""; mProtein = ""; mCarbs = ""; mFat = "" }
            } label: {
                Text("Add to today").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(canSaveManual ? Theme.acc : Theme.line))
                    .foregroundStyle(canSaveManual ? Color(hex: 0x0E0E10) : Theme.mut)
            }
            .disabled(!canSaveManual)
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.height(380)])
    }
    private var canSaveManual: Bool { (Double(mCals) ?? 0) > 0 }
    private func manualField(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut)
            TextField("0", text: text).keyboardType(.numberPad)
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.txt).padding(11)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1)))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: actions
    private func reload() async { meals = (try? await ScanAPI.shared.meals(on: LogDate.today)) ?? [] }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        errorMsg = nil
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) else {
            errorMsg = "Couldn't read that photo."; return
        }
        let jpeg = ui.jpegData(compressionQuality: 0.8) ?? data
        scanImage = ui
        scanB64 = jpeg.base64EncodedString()
        showScan = true
    }

    private func save(_ est: MealEstimate) async {
        try? await ScanAPI.shared.logMeal(est)
        await reload()
    }

    private func delete(_ m: MealLog) async {
        guard let id = m.id else { return }
        try? await ScanAPI.shared.deleteMeal(id: id)
        await reload()
    }
}
