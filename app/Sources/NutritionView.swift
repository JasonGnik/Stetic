import SwiftUI

// Daily nutrition: totals vs target, food grouped by meal (breakfast/lunch/dinner/
// snacks), scan / search / manual add per meal, and edit/delete on any logged item.
struct NutritionView: View {
    let target: PlanContent.Macros?

    @State private var meals: [MealLog] = []
    @State private var showCapture = false
    @State private var showSearch = false
    @State private var showManual = false
    @State private var editing: MealLog?
    @State private var errorMsg: String?
    @State private var addingType: MealType = .current()
    @State private var combineType: MealType?       // category whose foods we're saving as a meal
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
        .sheet(item: $editing) { meal in
            MealDetailView(log: meal, onChange: { Task { await reload() } },
                           onSaveAsMeal: { type in DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { combineType = type } })
        }
        .sheet(item: $combineType) { type in
            CombineFoodsSheet(type: type, foods: foodsIn(type)) { name, items in
                Task { await saveCombo(name, items) }
            }
        }
        .sheet(isPresented: $showSearch) {
            FoodSearchView(onPick: { hit in Task { await save(hit.asMeal) } },
                           onManual: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { startManual() } })
        }
        .fullScreenCover(isPresented: $showCapture) {
            FoodCaptureFlow(mealType: addingType, onLogged: { Task { await reload() } })
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
        Button { addingType = .current(); showCapture = true } label: {
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
                    Button { addingType = t; showCapture = true } label: { Label("Scan a photo", systemImage: "camera.fill") }
                    Button { addingType = t; showSearch = true } label: { Label("Search or add food", systemImage: "magnifyingglass") }
                    Button { addingType = t; showSaved = true } label: { Label("Saved meals", systemImage: "bookmark.fill") }
                    if !foodsIn(t).isEmpty {
                        Divider()
                        Button { combineType = t } label: { Label("Save \(t.label) as a meal", systemImage: "bookmark") }
                    }
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

    // All foods logged in a meal-type today (flattened across entries).
    private func foodsIn(_ t: MealType) -> [MealEstimate.Item] {
        meals.filter { MealType.bucket($0.meal_type) == t }.flatMap { m -> [MealEstimate.Item] in
            m.foods.isEmpty ? [.init(name: m.name, calories: m.calories, protein_g: m.protein_g, carbs_g: m.carbs_g, fat_g: m.fat_g)] : m.foods
        }
    }
    private func saveCombo(_ name: String, _ items: [MealEstimate.Item]) async {
        var est = MealEstimate(name: name.isEmpty ? "My meal" : name, items: items,
            calories: items.reduce(0) { $0 + $1.calories }, protein_g: items.reduce(0) { $0 + $1.protein_g },
            carbs_g: items.reduce(0) { $0 + $1.carbs_g }, fat_g: items.reduce(0) { $0 + $1.fat_g }, confidence: "combo")
        est.servings = 1
        try? await ScanAPI.shared.saveMeal(est)
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

// Pick which foods from a meal category to combine into one saved meal, then name it.
struct CombineFoodsSheet: View {
    let type: MealType
    let foods: [MealEstimate.Item]
    var onSave: (String, [MealEstimate.Item]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<Int> = []
    @State private var name = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Save \(type.label) as a meal").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                        .padding(8).background(Circle().fill(Theme.card))
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 8)

            TextField("", text: $name, prompt: Text("Meal name (e.g. My \(type.label.lowercased()))").foregroundStyle(Theme.mut))
                .font(.system(size: 16)).foregroundStyle(Theme.txt).padding(13)
                .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))
                .padding(.horizontal, 18)

            Text("Pick the foods to include").font(.system(size: 11, weight: .bold)).tracking(0.5).foregroundStyle(Theme.mut)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.top, 12)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(foods.enumerated()), id: \.offset) { idx, f in
                        let on = selected.contains(idx)
                        Button { if on { selected.remove(idx) } else { selected.insert(idx) } } label: {
                            HStack(spacing: 12) {
                                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 20)).foregroundStyle(on ? Theme.acc : Theme.line)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                                    if let p = f.portion, !p.isEmpty { Text(p).font(.system(size: 11)).foregroundStyle(Theme.mut) }
                                }
                                Spacer()
                                Text("\(Int(f.calories)) cal").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut)
                            }
                            .padding(.vertical, 11).padding(.horizontal, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? Theme.acc.opacity(0.5) : Theme.line, lineWidth: 1)))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)

            Button {
                let picked = foods.enumerated().filter { selected.contains($0.offset) }.map { $0.element }
                onSave(name, picked); dismiss()
            } label: {
                Text(selected.isEmpty ? "Pick at least one food" : "Save \(selected.count) as a meal")
                    .font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(selected.isEmpty ? Theme.line : Theme.acc))
                    .foregroundStyle(selected.isEmpty ? Theme.mut : Color(hex: 0x0E0E10))
            }
            .disabled(selected.isEmpty).padding(.horizontal, 18).padding(.bottom, 14)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { selected = Set(foods.indices) }   // all selected by default; deselect to exclude
    }
}
