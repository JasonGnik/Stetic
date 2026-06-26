import SwiftUI

// A logged meal as its component foods — edit per-food, add foods, move meal type,
// save the combo as a reusable meal, or delete. Totals are the sum of the foods.
struct MealDetailView: View {
    let log: MealLog
    var onChange: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var items: [MealEstimate.Item]
    @State private var mealType: MealType
    @State private var editTarget: EditTarget?
    @State private var showSearch = false
    @State private var savedCombo = false
    struct EditTarget: Identifiable { let id = UUID(); var index: Int? }

    init(log: MealLog, onChange: @escaping () -> Void) {
        self.log = log; self.onChange = onChange
        _name = State(initialValue: log.name)
        _items = State(initialValue: log.foods.isEmpty
            ? [.init(name: log.name, calories: log.calories, protein_g: log.protein_g, carbs_g: log.carbs_g, fat_g: log.fat_g)]
            : log.foods)
        _mealType = State(initialValue: MealType.bucket(log.meal_type))
    }

    private var totalCals: Double { items.reduce(0) { $0 + $1.calories } }
    private var totalP: Double { items.reduce(0) { $0 + $1.protein_g } }
    private var totalC: Double { items.reduce(0) { $0 + $1.carbs_g } }
    private var totalF: Double { items.reduce(0) { $0 + $1.fat_g } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Meal").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                        .padding(8).background(Circle().fill(Theme.card))
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 14) {
                    TextField("", text: $name, prompt: Text("Meal name").foregroundStyle(Theme.mut))
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt).padding(12)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))

                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill").font(.system(size: 20)).foregroundStyle(Theme.acc)
                        Text("\(Int(totalCals))").font(.system(size: 28, weight: .heavy)).foregroundStyle(Theme.txt)
                        Text("cal").font(.system(size: 13)).foregroundStyle(Theme.mut)
                        Spacer()
                        Text("P \(Int(totalP)) · C \(Int(totalC)) · F \(Int(totalF))").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
                    }
                    .padding(16).background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))

                    HStack {
                        Text("Foods").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                        Spacer()
                        Button { showSearch = true } label: {
                            HStack(spacing: 4) { Image(systemName: "plus").font(.system(size: 12, weight: .bold)); Text("Add food").font(.system(size: 13, weight: .semibold)) }
                                .foregroundStyle(Theme.acc)
                        }
                    }
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        Button { editTarget = EditTarget(index: idx) } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                                    if let p = item.portion, !p.isEmpty { Text(p).font(.system(size: 11)).foregroundStyle(Theme.mut) }
                                }
                                Spacer()
                                Text("\(Int(item.calories)) cal").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut)
                                Button { items.remove(at: idx) } label: {
                                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.mut)
                                        .frame(width: 26, height: 26).background(Circle().fill(Theme.bg))
                                }.buttonStyle(.plain)
                            }
                            .padding(.vertical, 10).padding(.horizontal, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1)))
                        }.buttonStyle(.plain)
                    }

                    Button { Task { await saveCombo() } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: savedCombo ? "bookmark.fill" : "bookmark")
                            Text(savedCombo ? "Saved to your meals" : "Save this as a meal")
                        }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.acc)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))
                    }
                    .disabled(savedCombo).padding(.top, 4)
                }
                .padding(.horizontal, 18).padding(.top, 6).padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 10) {
                Button { Task { await delete() } } label: {
                    Text("Delete").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card)).foregroundStyle(Theme.red)
                }
                Button { Task { await saveChanges() } } label: {
                    Text("Save").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(items.isEmpty ? Theme.line : Theme.acc))
                        .foregroundStyle(items.isEmpty ? Theme.mut : Color(hex: 0x0E0E10))
                }.disabled(items.isEmpty)
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 14)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $editTarget) { t in
            FoodItemEditor(item: t.index.map { items[$0] }) { result in
                if let i = t.index { items[i] = result } else { items.append(result) }
                editTarget = nil
            } onCancel: { editTarget = nil }
            .presentationDetents([.height(440)])
        }
        .sheet(isPresented: $showSearch) {
            FoodSearchView(onPick: { hit in items.append(hit.asItem) },
                           onManual: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { editTarget = EditTarget(index: nil) } })
        }
    }

    private func estimate() -> MealEstimate {
        MealEstimate(name: name.isEmpty ? "Meal" : name, items: items, calories: totalCals, protein_g: totalP, carbs_g: totalC, fat_g: totalF, confidence: "logged")
    }
    private func saveChanges() async {
        guard let id = log.id else { dismiss(); return }
        try? await ScanAPI.shared.updateMeal(id: id, name: name.isEmpty ? "Meal" : name,
            calories: totalCals, protein_g: totalP, carbs_g: totalC, fat_g: totalF, mealType: mealType.rawValue, items: items)
        onChange(); dismiss()
    }
    private func delete() async {
        if let id = log.id { try? await ScanAPI.shared.deleteMeal(id: id) }
        onChange(); dismiss()
    }
    private func saveCombo() async {
        try? await ScanAPI.shared.saveMeal(estimate())
        await MainActor.run { withAnimation { savedCombo = true } }
    }
}

// Add/edit one food's name, portion, and macros.
struct FoodItemEditor: View {
    let item: MealEstimate.Item?
    var onSave: (MealEstimate.Item) -> Void
    var onCancel: () -> Void

    @State private var name = ""
    @State private var portion = ""
    @State private var cals = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(item == nil ? "Add food" : "Edit food").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
                Spacer()
                Button { onCancel() } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut) }
            }
            field("Food name", $name)
            field("Portion (e.g. 3 eggs)", $portion)
            HStack(spacing: 8) { numField("Calories", $cals); numField("Protein", $protein) }
            HStack(spacing: 8) { numField("Carbs", $carbs); numField("Fat", $fat) }
            Button {
                var it = item ?? MealEstimate.Item(name: "")
                it.name = name.isEmpty ? "Food" : name
                it.portion = portion.isEmpty ? nil : portion
                it.calories = Double(cals) ?? 0; it.protein_g = Double(protein) ?? 0
                it.carbs_g = Double(carbs) ?? 0; it.fat_g = Double(fat) ?? 0
                onSave(it)
            } label: {
                Text("Save").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill((Double(cals) ?? 0) > 0 ? Theme.acc : Theme.line))
                    .foregroundStyle((Double(cals) ?? 0) > 0 ? Color(hex: 0x0E0E10) : Theme.mut)
            }.disabled((Double(cals) ?? 0) <= 0)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 18)
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            if let item {
                name = item.name; portion = item.portion ?? ""
                cals = item.calories > 0 ? "\(Int(item.calories))" : ""
                protein = item.protein_g > 0 ? "\(Int(item.protein_g))" : ""
                carbs = item.carbs_g > 0 ? "\(Int(item.carbs_g))" : ""
                fat = item.fat_g > 0 ? "\(Int(item.fat_g))" : ""
            }
        }
    }
    private func field(_ label: String, _ text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(label).foregroundStyle(Theme.mut))
            .font(.system(size: 15)).foregroundStyle(Theme.txt).padding(13)
            .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))
    }
    private func numField(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut)
            TextField("0", text: text).keyboardType(.numberPad)
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.txt).padding(11)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1)))
        }
    }
}
