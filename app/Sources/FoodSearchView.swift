import SwiftUI

// Search the food catalog (USDA + OpenFoodFacts) and pick a result. Caller decides
// whether the pick becomes a logged meal or an ingredient.
struct FoodSearchView: View {
    var onPick: (FoodHit) -> Void
    var onManual: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [FoodHit] = []
    @State private var searching = false
    @State private var searched = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add food").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                        .padding(8).background(Circle().fill(Theme.card))
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 10)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(Theme.mut)
                TextField("", text: $query, prompt: Text("Search foods (e.g. chicken breast)").foregroundStyle(Theme.mut))
                    .font(.system(size: 15)).foregroundStyle(Theme.txt)
                    .submitLabel(.search).onSubmit { Task { await search() } }
                if !query.isEmpty {
                    Button { query = ""; results = []; searched = false } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 15)).foregroundStyle(Theme.mut)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1)))
            .padding(.horizontal, 18)

            if let onManual {
                Button { onManual(); dismiss() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil").font(.system(size: 12, weight: .bold))
                        Text("Create a food manually").font(.system(size: 13, weight: .semibold))
                    }.foregroundStyle(Theme.acc)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1)))
                    .padding(.horizontal, 18)
                }
                .padding(.top, 8)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    // local suggestions (instant, no API)
                    if !suggestions.isEmpty {
                        sectionLabel("SUGGESTIONS")
                        ForEach(suggestions) { row($0) }
                    }
                    // press-to-search the full catalog (conserves API calls)
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty && !searching {
                        Button { Task { await search() } } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .bold))
                                Text(searched ? "Search again" : "Search the full catalog").font(.system(size: 13, weight: .semibold))
                            }.foregroundStyle(Theme.acc)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1)))
                        }.padding(.top, 4)
                    }
                    if searching { ProgressView().tint(Theme.acc).frame(maxWidth: .infinity).padding(.top, 20) }
                    if searched {
                        sectionLabel("CATALOG")
                        if results.isEmpty { Text("No catalog matches.").font(.system(size: 13)).foregroundStyle(Theme.mut) }
                        ForEach(results) { row($0) }
                    }
                }
                .padding(.horizontal, 18).padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    // Instant, local suggestions while typing — no API call.
    private var suggestions: [FoodHit] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 1 else { return [] }
        return CommonFoods.all.filter { $0.name.lowercased().contains(q) }.prefix(8).map { $0 }
    }

    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 10.5, weight: .bold)).tracking(1).foregroundStyle(Theme.mut).padding(.top, 6)
    }

    private func row(_ hit: FoodHit) -> some View {
        Button { onPick(hit); dismiss() } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                    Text([hit.brand.isEmpty ? nil : hit.brand, hit.portion].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11)).foregroundStyle(Theme.mut).lineLimit(1)
                }
                Spacer()
                Text("\(Int(hit.calories)) cal").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                Image(systemName: "plus.circle.fill").font(.system(size: 18)).foregroundStyle(Theme.acc)
            }
            .padding(.vertical, 11).padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return }
        searching = true
        let hits = (try? await ScanAPI.shared.searchFoods(q)) ?? []
        await MainActor.run { results = hits; searching = false; searched = true }
    }
}

// A small built-in catalog for instant, offline suggestions (per common serving).
enum CommonFoods {
    static let all: [FoodHit] = [
        .init(name: "Chicken breast", portion: "100 g", calories: 165, protein_g: 31, carbs_g: 0, fat_g: 4),
        .init(name: "Chicken thigh", portion: "100 g", calories: 209, protein_g: 26, carbs_g: 0, fat_g: 11),
        .init(name: "Ground beef (90/10)", portion: "100 g", calories: 176, protein_g: 20, carbs_g: 0, fat_g: 10),
        .init(name: "Steak (sirloin)", portion: "100 g", calories: 206, protein_g: 27, carbs_g: 0, fat_g: 10),
        .init(name: "Salmon", portion: "100 g", calories: 208, protein_g: 20, carbs_g: 0, fat_g: 13),
        .init(name: "Tuna (canned, water)", portion: "100 g", calories: 116, protein_g: 26, carbs_g: 0, fat_g: 1),
        .init(name: "Shrimp", portion: "100 g", calories: 99, protein_g: 24, carbs_g: 0, fat_g: 1),
        .init(name: "Eggs", portion: "1 large", calories: 72, protein_g: 6, carbs_g: 0, fat_g: 5),
        .init(name: "Egg whites", portion: "100 g", calories: 52, protein_g: 11, carbs_g: 1, fat_g: 0),
        .init(name: "White rice (cooked)", portion: "100 g", calories: 130, protein_g: 3, carbs_g: 28, fat_g: 0),
        .init(name: "Brown rice (cooked)", portion: "100 g", calories: 123, protein_g: 3, carbs_g: 26, fat_g: 1),
        .init(name: "Oats (dry)", portion: "40 g", calories: 150, protein_g: 5, carbs_g: 27, fat_g: 3),
        .init(name: "Sweet potato", portion: "100 g", calories: 86, protein_g: 2, carbs_g: 20, fat_g: 0),
        .init(name: "Potato", portion: "100 g", calories: 77, protein_g: 2, carbs_g: 17, fat_g: 0),
        .init(name: "Pasta (cooked)", portion: "100 g", calories: 158, protein_g: 6, carbs_g: 31, fat_g: 1),
        .init(name: "Bread (slice)", portion: "1 slice", calories: 80, protein_g: 4, carbs_g: 14, fat_g: 1),
        .init(name: "Banana", portion: "1 medium", calories: 105, protein_g: 1, carbs_g: 27, fat_g: 0),
        .init(name: "Apple", portion: "1 medium", calories: 95, protein_g: 0, carbs_g: 25, fat_g: 0),
        .init(name: "Greek yogurt (nonfat)", portion: "170 g", calories: 100, protein_g: 18, carbs_g: 6, fat_g: 0),
        .init(name: "Cottage cheese", portion: "100 g", calories: 98, protein_g: 11, carbs_g: 3, fat_g: 4),
        .init(name: "Milk (2%)", portion: "1 cup", calories: 122, protein_g: 8, carbs_g: 12, fat_g: 5),
        .init(name: "Whey protein", portion: "1 scoop", calories: 120, protein_g: 24, carbs_g: 3, fat_g: 1),
        .init(name: "Almonds", portion: "28 g", calories: 164, protein_g: 6, carbs_g: 6, fat_g: 14),
        .init(name: "Peanut butter", portion: "1 tbsp", calories: 94, protein_g: 4, carbs_g: 3, fat_g: 8),
        .init(name: "Olive oil", portion: "1 tbsp", calories: 119, protein_g: 0, carbs_g: 0, fat_g: 14),
        .init(name: "Avocado", portion: "1/2", calories: 120, protein_g: 1, carbs_g: 6, fat_g: 11),
        .init(name: "Broccoli", portion: "100 g", calories: 34, protein_g: 3, carbs_g: 7, fat_g: 0),
        .init(name: "Mixed greens", portion: "100 g", calories: 17, protein_g: 2, carbs_g: 3, fat_g: 0),
        .init(name: "Black beans (cooked)", portion: "100 g", calories: 132, protein_g: 9, carbs_g: 24, fat_g: 0),
        .init(name: "Cheddar cheese", portion: "28 g", calories: 113, protein_g: 7, carbs_g: 0, fat_g: 9),
    ]
}
