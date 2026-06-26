import SwiftUI

// A logged meal as its component foods — edit per-food, add foods, move meal type,
// save the combo as a reusable meal, or delete. Totals are the sum of the foods.
struct MealDetailView: View {
    let log: MealLog
    var onChange: () -> Void
    var onSaveAsMeal: (MealType) -> Void = { _ in }   // open the category food-picker to save a combo
    @Environment(\.dismiss) private var dismiss

    @State private var items: [MealEstimate.Item]
    @State private var editTarget: EditTarget?
    @State private var showSearch = false
    private var mealType: MealType { MealType.bucket(log.meal_type) }
    struct EditTarget: Identifiable { let id = UUID(); var index: Int? }

    init(log: MealLog, onChange: @escaping () -> Void, onSaveAsMeal: @escaping (MealType) -> Void = { _ in }) {
        self.log = log; self.onChange = onChange; self.onSaveAsMeal = onSaveAsMeal
        _items = State(initialValue: log.foods.isEmpty
            ? [.init(name: log.name, calories: log.calories, protein_g: log.protein_g, carbs_g: log.carbs_g, fat_g: log.fat_g)]
            : log.foods)
    }

    private var totalCals: Double { items.reduce(0) { $0 + $1.calories } }
    private var totalP: Double { items.reduce(0) { $0 + $1.protein_g } }
    private var totalC: Double { items.reduce(0) { $0 + $1.carbs_g } }
    private var totalF: Double { items.reduce(0) { $0 + $1.fat_g } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: mealType.icon).font(.system(size: 14)).foregroundStyle(Theme.acc)
                VStack(alignment: .leading, spacing: 1) {
                    Text(log.name).font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt).lineLimit(1)
                    Text(mealType.label).font(.system(size: 11)).foregroundStyle(Theme.mut)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                        .padding(8).background(Circle().fill(Theme.card))
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 14) {
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

                    Button { onSaveAsMeal(mealType); dismiss() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bookmark")
                            Text("Save \(mealType.label) as a meal")
                        }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.acc)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))
                    }
                    .padding(.top, 4)
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
        .keyboardDone()
        .sheet(item: $editTarget) { t in
            FoodItemEditor(item: t.index.map { items[$0] }) { result in
                if let i = t.index { items[i] = result } else { items.append(result) }
                editTarget = nil
            } onCancel: { editTarget = nil }
            .presentationDetents([.height(500)])
        }
        .sheet(isPresented: $showSearch) {
            FoodSearchView(onPick: { hit in items.append(hit.asItem) },
                           onManual: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { editTarget = EditTarget(index: nil) } })
        }
    }

    private func saveChanges() async {
        guard let id = log.id else { dismiss(); return }
        try? await ScanAPI.shared.updateMeal(id: id, name: log.name,
            calories: totalCals, protein_g: totalP, carbs_g: totalC, fat_g: totalF, mealType: mealType.rawValue, items: items)
        onChange(); dismiss()
    }
    private func delete() async {
        if let id = log.id { try? await ScanAPI.shared.deleteMeal(id: id) }
        onChange(); dismiss()
    }
}

// Add/edit one food: name + a TYPED measure (quantity + unit). For a known food
// (from a scan or the catalog) the macros are calculated automatically from its
// per-unit values as you change the amount. A brand-new manual food lets you enter
// the macros once.
struct FoodItemEditor: View {
    let item: MealEstimate.Item?
    var onSave: (MealEstimate.Item) -> Void
    var onCancel: () -> Void

    @State private var name = ""
    @State private var qtyText = "1"
    @State private var unit = "serving"
    @State private var perCal = 0.0   // per 1 unit
    @State private var perP = 0.0
    @State private var perC = 0.0
    @State private var perF = 0.0
    @State private var mCal = ""       // manual entry (total)
    @State private var mP = ""
    @State private var mC = ""
    @State private var mF = ""
    @State private var manual = false
    private let units = ["serving", "g", "oz", "cup", "tbsp", "piece", "ml"]

    private var qty: Double { max(0, Double(qtyText) ?? 0) }
    private func tot(_ per: Double) -> Int { Int((per * qty).rounded()) }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(item == nil ? "Add food" : "Edit food").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
                Spacer()
                Button { onCancel() } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut) }
            }
            field("Food name", $name)
            HStack(spacing: 10) {
                TextField("1", text: $qtyText).keyboardType(.decimalPad)
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt).multilineTextAlignment(.center)
                    .padding(.vertical, 12).frame(width: 90)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))
                Menu {
                    ForEach(units, id: \.self) { u in Button(u) { unit = u } }
                } label: {
                    HStack(spacing: 4) { Text(unit).font(.system(size: 15, weight: .semibold)); Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)) }
                        .foregroundStyle(Theme.txt).frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))
                }
            }

            if manual {
                Text("Enter the macros for this amount").font(.system(size: 11)).foregroundStyle(Theme.mut).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) { numField("Calories", $mCal); numField("Protein", $mP) }
                HStack(spacing: 8) { numField("Carbs", $mC); numField("Fat", $mF) }
            } else {
                // auto-calculated from the food's per-unit data
                HStack(spacing: 8) {
                    macroTile("Calories", tot(perCal)); macroTile("Protein", tot(perP), "g")
                    macroTile("Carbs", tot(perC), "g"); macroTile("Fat", tot(perF), "g")
                }
                Text("Calculated for \(qtyText.isEmpty ? "0" : qtyText) \(unit).").font(.system(size: 11)).foregroundStyle(Theme.mut)
            }

            Button { save() } label: {
                Text("Save").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(canSave ? Theme.acc : Theme.line))
                    .foregroundStyle(canSave ? Color(hex: 0x0E0E10) : Theme.mut)
            }.disabled(!canSave)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 18)
        .background(Theme.bg.ignoresSafeArea())
        .keyboardDone()
        .onAppear(perform: load)
    }

    private var canSave: Bool { qty > 0 && (manual ? (Double(mCal) ?? 0) > 0 : perCal > 0) }

    private func load() {
        guard let item else { manual = true; qtyText = "1"; return }
        name = item.name
        let parsed = MealEstimate.Item.parsePortion(item.portion)
        let q = item.quantity != 1 ? item.quantity : parsed.0
        unit = item.unit != "serving" ? item.unit : parsed.1
        qtyText = q == q.rounded() ? "\(Int(q))" : String(format: "%.1f", q)
        let base = max(q, 0.0001)
        if item.calories > 0 {
            manual = false
            perCal = item.calories / base; perP = item.protein_g / base; perC = item.carbs_g / base; perF = item.fat_g / base
        } else {
            manual = true
        }
    }

    private func save() {
        var it = item ?? MealEstimate.Item(name: "")
        it.name = name.isEmpty ? "Food" : name
        it.quantity = qty; it.unit = unit
        it.portion = "\(qtyText) \(unit)"
        if manual {
            it.calories = Double(mCal) ?? 0; it.protein_g = Double(mP) ?? 0
            it.carbs_g = Double(mC) ?? 0; it.fat_g = Double(mF) ?? 0
        } else {
            it.calories = Double(tot(perCal)); it.protein_g = Double(tot(perP))
            it.carbs_g = Double(tot(perC)); it.fat_g = Double(tot(perF))
        }
        onSave(it)
    }

    private func macroTile(_ label: String, _ value: Int, _ suffix: String = "") -> some View {
        VStack(spacing: 3) {
            Text("\(value)\(suffix)").font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.txt)
            Text(label).font(.system(size: 9.5)).foregroundStyle(Theme.mut)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))
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
