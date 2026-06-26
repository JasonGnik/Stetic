import SwiftUI

// Daily nutrition: totals vs target, food grouped by meal (breakfast/lunch/dinner/
// snacks), scan / search / manual add per meal, and edit/delete on any logged item.
struct NutritionView: View {
    let target: PlanContent.Macros?

    @State private var meals: [MealLog] = []
    @State private var scanImage: UIImage?
    @State private var scanB64: String?
    @State private var showScan = false
    @State private var showCamera = false
    @State private var pendingPresent = false
    @State private var showSearch = false
    @State private var showManual = false
    @State private var editing: MealLog?
    @State private var errorMsg: String?
    @State private var addingType: MealType = .current()
    @State private var scanMode = "meal"
    @State private var presetMeal: MealEstimate?
    @State private var pendingBarcode: String?
    @State private var showIdeas = false
    @State private var showSaved = false
    @State private var showReminders = false
    @State private var showCraving = false

    // manual / edit fields
    @State private var mName = ""
    @State private var mCals = ""
    @State private var mProtein = ""
    @State private var mCarbs = ""
    @State private var mFat = ""

    private var cals: Double { meals.reduce(0) { $0 + $1.calories } }
    private var protein: Double { meals.reduce(0) { $0 + $1.protein_g } }
    private var carbs: Double { meals.reduce(0) { $0 + $1.carbs_g } }
    private var fat: Double { meals.reduce(0) { $0 + $1.fat_g } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Food").font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.txt)
                    Spacer()
                    Button { showReminders = true } label: {
                        Image(systemName: "bell.badge").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.acc)
                            .frame(width: 38, height: 38).background(Circle().fill(Theme.card))
                    }
                }
                summaryCard
                HStack(spacing: 10) { scanButton; ideasButton }
                if let errorMsg { Text(errorMsg).font(.system(size: 12)).foregroundStyle(Theme.red) }
                ForEach(MealType.allCases) { mealSection($0) }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
        }
        .background(Theme.bg.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .task { await reload() }
        .onChange(of: showCamera) { _, shown in
            if !shown && pendingPresent {
                pendingPresent = false
                if let code = pendingBarcode { pendingBarcode = nil; Task { await resolveBarcode(code) } }
                else { showScan = true }
            }
        }
        .sheet(isPresented: $showManual) { manualSheet }
        .sheet(isPresented: $showIdeas) {
            MealIdeasView(onLog: { meal in Task { addingType = meal.type; await save(meal.asMeal) } },
                          onCraving: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showCraving = true } })
        }
        .sheet(isPresented: $showSaved) {
            SavedMealsView { sm in Task { await save(sm.asEstimate) } }
        }
        .sheet(isPresented: $showReminders) { MealRemindersView() }
        .sheet(isPresented: $showCraving) {
            CravingView(target: target, consumed: (cals, protein, carbs, fat)) { est in
                Task { addingType = .current(); await save(est) }
            }
        }
        .sheet(item: $editing) { MealDetailView(log: $0, onChange: { Task { await reload() } }) }
        .sheet(isPresented: $showSearch) {
            FoodSearchView(onPick: { hit in Task { await save(hit.asMeal) } },
                           onManual: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { startManual() } })
        }
        .fullScreenCover(isPresented: $showCamera) {
            FoodCameraView(
                onCapture: { img, m in
                    scanImage = img
                    scanB64 = (img.jpegData(compressionQuality: 0.8) ?? Data()).base64EncodedString()
                    scanMode = (m == .foodLabel) ? "label" : "meal"
                    presetMeal = nil; pendingBarcode = nil
                    pendingPresent = true; showCamera = false
                },
                onBarcode: { code in
                    pendingBarcode = code; pendingPresent = true; showCamera = false
                })
        }
        .fullScreenCover(isPresented: $showScan) {
            if let preset = presetMeal {
                MealScanView(image: UIImage(), dataB64: "", mealType: addingType.rawValue,
                             onLogged: { Task { await reload() } }, preset: preset)
            } else if let img = scanImage, let b64 = scanB64 {
                MealScanView(image: img, dataB64: b64, mealType: addingType.rawValue, scanMode: scanMode,
                             onLogged: { Task { await reload() } })
            }
        }
    }

    private func resolveBarcode(_ code: String) async {
        let hit = try? await ScanAPI.shared.searchBarcode(code)
        await MainActor.run {
            if let hit { presetMeal = hit.asMeal; showScan = true }
            else { errorMsg = "Couldn't find that barcode — try Scan Food instead." }
        }
    }

    // MARK: header pieces
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
        Button { addingType = .current(); showCamera = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill").font(.system(size: 15, weight: .bold))
                Text("Scan a meal").font(.system(size: 15, weight: .bold))
            }
            .frame(maxWidth: .infinity).padding(14)
            .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
            .foregroundStyle(Color(hex: 0x0E0E10))
        }
    }

    private var ideasButton: some View {
        Button { showIdeas = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill").font(.system(size: 14, weight: .bold))
                Text("Ideas & cravings").font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity).padding(14)
            .background(RoundedRectangle(cornerRadius: 13).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.line, lineWidth: 1)))
            .foregroundStyle(Theme.txt)
        }
    }

    // MARK: meal sections
    private func mealSection(_ t: MealType) -> some View {
        let items = meals.filter { MealType.bucket($0.meal_type) == t }
        let sectionCals = items.reduce(0) { $0 + $1.calories }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: t.icon).font(.system(size: 13)).foregroundStyle(Theme.acc)
                Text(t.label).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                Spacer()
                if sectionCals > 0 {
                    Text("\(Int(sectionCals)) cal").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
                }
                Menu {
                    Button { addingType = t; showCamera = true } label: { Label("Scan a photo", systemImage: "camera.fill") }
                    Button { addingType = t; showSearch = true } label: { Label("Search or add food", systemImage: "magnifyingglass") }
                    Button { addingType = t; showSaved = true } label: { Label("Saved meals", systemImage: "bookmark.fill") }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.acc)
                }
            }
            if items.isEmpty {
                Text("Nothing logged").font(.system(size: 12)).foregroundStyle(Theme.mut)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(items) { mealRow($0) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card.opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1)))
    }

    private func mealRow(_ m: MealLog) -> some View {
        let count = m.foods.count
        return Button { editing = m } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(m.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                    Text((count > 1 ? "\(count) foods · " : "") + "P \(Int(m.protein_g)) · C \(Int(m.carbs_g)) · F \(Int(m.fat_g))")
                        .font(.system(size: 11)).foregroundStyle(Theme.mut)
                }
                Spacer()
                Text("\(Int(m.calories)) cal").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.mut)
            }
            .padding(.vertical, 11).padding(.horizontal, 13)
            .background(RoundedRectangle(cornerRadius: 11).fill(Theme.bg))
        }
        .buttonStyle(.plain)
    }

    // MARK: manual + edit sheets
    private func startManual() {
        mName = ""; mCals = ""; mProtein = ""; mCarbs = ""; mFat = ""; showManual = true
    }
    private var manualSheet: some View {
        mealForm(title: "Add a meal", showDelete: false, onSave: {
            let est = MealEstimate(name: mName.isEmpty ? "Meal" : mName,
                calories: Double(mCals) ?? 0, protein_g: Double(mProtein) ?? 0,
                carbs_g: Double(mCarbs) ?? 0, fat_g: Double(mFat) ?? 0, confidence: "manual")
            Task { showManual = false; await save(est); }
        }, onDelete: {})
    }

    private func mealForm(title: String, showDelete: Bool, onSave: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        VStack(spacing: 14) {
            Capsule().fill(Theme.line).frame(width: 38, height: 5).padding(.top, 10)
            Text(title).font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
            Picker("Meal", selection: $addingType) {
                ForEach(MealType.allCases) { Text($0.label).tag($0) }
            }.pickerStyle(.segmented)
            TextField("", text: $mName, prompt: Text("Meal name").foregroundStyle(Theme.mut))
                .font(.system(size: 16)).foregroundStyle(Theme.txt).padding(13)
                .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))
            HStack(spacing: 8) { manualField("Calories", $mCals); manualField("Protein", $mProtein) }
            HStack(spacing: 8) { manualField("Carbs", $mCarbs); manualField("Fat", $mFat) }
            Button { onSave() } label: {
                Text("Save").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(canSaveManual ? Theme.acc : Theme.line))
                    .foregroundStyle(canSaveManual ? Color(hex: 0x0E0E10) : Theme.mut)
            }
            .disabled(!canSaveManual)
            if showDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Text("Delete").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.red)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.height(showDelete ? 470 : 430)])
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

    private func save(_ est: MealEstimate) async {
        try? await ScanAPI.shared.logMeal(est, mealType: addingType.rawValue)
        await reload()
    }

    private func delete(_ m: MealLog) async {
        guard let id = m.id else { return }
        try? await ScanAPI.shared.deleteMeal(id: id)
        await reload()
    }
}
