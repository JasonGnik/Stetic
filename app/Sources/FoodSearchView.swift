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

            ScrollView {
                LazyVStack(spacing: 8) {
                    if searching {
                        ProgressView().tint(Theme.acc).padding(.top, 30)
                    } else if searched && results.isEmpty {
                        VStack(spacing: 6) {
                            Text("No matches").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                            if let onManual {
                                Button { onManual(); dismiss() } label: {
                                    Text("Enter it manually").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.acc)
                                }
                            }
                        }.padding(.top, 30)
                    }
                    ForEach(results) { hit in row(hit) }
                }
                .padding(.horizontal, 18).padding(.top, 12)
            }
            .scrollIndicators(.hidden)

            if let onManual, !results.isEmpty {
                Button { onManual(); dismiss() } label: {
                    Text("Can't find it? Enter manually").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.acc)
                }
                .padding(.vertical, 12)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .task(id: query) {
            guard query.trimmingCharacters(in: .whitespaces).count >= 2 else { return }
            try? await Task.sleep(nanoseconds: 400_000_000)   // debounce
            if !Task.isCancelled { await search() }
        }
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
