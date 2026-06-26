import SwiftUI

// A whole meal category (Breakfast/Lunch/Dinner/Snacks) as a flat list of its foods.
// Title is just the meal name. Edit/remove/add foods, or save the whole thing as a meal.
struct MealCategoryView: View {
    let type: MealType
    var onChange: () -> Void
    var onSaveAsMeal: (MealType) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var meals: [MealLog] = []
    @State private var editTarget: FoodRef?
    @State private var addingFood = false
    @State private var showSearch = false

    struct FoodRef: Identifiable { let id: String; let logId: String; let idx: Int; let item: MealEstimate.Item }

    // Flat foods across every logged entry in this category.
    private var rows: [FoodRef] {
        meals.flatMap { log -> [FoodRef] in
            guard let id = log.id else { return [] }
            let foods = log.foods.isEmpty
                ? [MealEstimate.Item(name: log.name, calories: log.calories, protein_g: log.protein_g, carbs_g: log.carbs_g, fat_g: log.fat_g)]
                : log.foods
            return foods.enumerated().map { FoodRef(id: "\(id)-\($0.offset)", logId: id, idx: $0.offset, item: $0.element) }
        }
    }
    private var totCal: Double { rows.reduce(0) { $0 + $1.item.calories } }
    private var totP: Double { rows.reduce(0) { $0 + $1.item.protein_g } }
    private var totC: Double { rows.reduce(0) { $0 + $1.item.carbs_g } }
    private var totF: Double { rows.reduce(0) { $0 + $1.item.fat_g } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: type.icon).font(.system(size: 15)).foregroundStyle(Theme.acc)
                Text(type.label).font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.txt)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                        .padding(8).background(Circle().fill(Theme.card))
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill").font(.system(size: 20)).foregroundStyle(Theme.acc)
                        Text("\(Int(totCal))").font(.system(size: 28, weight: .heavy)).foregroundStyle(Theme.txt)
                        Text("cal").font(.system(size: 13)).foregroundStyle(Theme.mut)
                        Spacer()
                        Text("P \(Int(totP)) · C \(Int(totC)) · F \(Int(totF))").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
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
                    if rows.isEmpty {
                        Text("Nothing logged yet.").font(.system(size: 13)).foregroundStyle(Theme.mut).frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(rows) { row in foodRow(row) }
                    }

                    if !rows.isEmpty {
                        Button { onSaveAsMeal(type); dismiss() } label: {
                            HStack(spacing: 6) { Image(systemName: "bookmark"); Text("Save \(type.label.lowercased()) as a meal") }
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.acc)
                                .frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))
                        }.padding(.top, 4)
                    }
                }
                .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg.ignoresSafeArea())
        .task { await load() }
        .sheet(item: $editTarget) { ref in
            FoodItemEditor(item: ref.item) { updated in
                Task { await editFood(ref, updated) }; editTarget = nil
            } onCancel: { editTarget = nil }
            .presentationDetents([.height(500)])
        }
        .sheet(isPresented: $showSearch) {
            FoodSearchView(onPick: { hit in Task { await addFood(hit.asItem) } },
                           onManual: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { addingFood = true } })
        }
        .sheet(isPresented: $addingFood) {
            FoodItemEditor(item: nil) { newItem in
                Task { await addFood(newItem) }; addingFood = false
            } onCancel: { addingFood = false }
            .presentationDetents([.height(500)])
        }
    }

    private func foodRow(_ row: FoodRef) -> some View {
        Button { editTarget = row } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.item.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    if let p = row.item.portion, !p.isEmpty { Text(p).font(.system(size: 11)).foregroundStyle(Theme.mut) }
                }
                Spacer()
                Text("\(Int(row.item.calories)) cal").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut)
                Button { Task { await removeFood(row) } } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.mut)
                        .frame(width: 26, height: 26).background(Circle().fill(Theme.bg))
                }.buttonStyle(.plain)
            }
            .padding(.vertical, 11).padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1)))
        }.buttonStyle(.plain)
    }

    // MARK: data
    private func load() async {
        let all = (try? await ScanAPI.shared.meals(on: LogDate.today)) ?? []
        await MainActor.run { meals = all.filter { MealType.bucket($0.meal_type) == type } }
    }
    private func itemsFor(_ log: MealLog) -> [MealEstimate.Item] {
        log.foods.isEmpty ? [.init(name: log.name, calories: log.calories, protein_g: log.protein_g, carbs_g: log.carbs_g, fat_g: log.fat_g)] : log.foods
    }
    private func persist(_ log: MealLog, _ items: [MealEstimate.Item]) async {
        guard let id = log.id else { return }
        if items.isEmpty { try? await ScanAPI.shared.deleteMeal(id: id) }
        else {
            try? await ScanAPI.shared.updateMeal(id: id, name: log.name,
                calories: items.reduce(0) { $0 + $1.calories }, protein_g: items.reduce(0) { $0 + $1.protein_g },
                carbs_g: items.reduce(0) { $0 + $1.carbs_g }, fat_g: items.reduce(0) { $0 + $1.fat_g },
                mealType: MealType.bucket(log.meal_type).rawValue, items: items)
        }
        await load(); onChange()
    }
    private func editFood(_ ref: FoodRef, _ updated: MealEstimate.Item) async {
        guard let log = meals.first(where: { $0.id == ref.logId }) else { return }
        var items = itemsFor(log); guard ref.idx < items.count else { return }
        items[ref.idx] = updated
        await persist(log, items)
    }
    private func removeFood(_ ref: FoodRef) async {
        guard let log = meals.first(where: { $0.id == ref.logId }) else { return }
        var items = itemsFor(log); guard ref.idx < items.count else { return }
        items.remove(at: ref.idx)
        await persist(log, items)
    }
    private func addFood(_ item: MealEstimate.Item) async {
        var est = MealEstimate(name: item.name, items: [item], calories: item.calories, protein_g: item.protein_g, carbs_g: item.carbs_g, fat_g: item.fat_g, confidence: "manual")
        est.servings = 1
        try? await ScanAPI.shared.logMeal(est, mealType: type.rawValue)
        await load(); onChange()
    }
}
