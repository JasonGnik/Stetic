import SwiftUI

// The user's saved meals — re-log in one tap, or delete.
struct SavedMealsView: View {
    var onLog: (SavedMeal) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var meals: [SavedMeal] = []
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Saved meals").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                        .padding(8).background(Circle().fill(Theme.card))
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 8)

            if loading {
                Spacer(); ProgressView().tint(Theme.acc); Spacer()
            } else if meals.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "bookmark").font(.system(size: 26)).foregroundStyle(Theme.mut)
                    Text("No saved meals yet").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    Text("Build a meal in a scan, then tap the bookmark to save it.")
                        .font(.system(size: 12)).foregroundStyle(Theme.mut).multilineTextAlignment(.center).padding(.horizontal, 40)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(meals) { row($0) }
                    }
                    .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .task { await load() }
    }

    private func row(_ m: SavedMeal) -> some View {
        Button { onLog(m); dismiss() } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(m.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                    Text("\(Int(m.calories)) cal · P \(Int(m.protein_g)) · C \(Int(m.carbs_g)) · F \(Int(m.fat_g))")
                        .font(.system(size: 11)).foregroundStyle(Theme.mut)
                }
                Spacer()
                Button { Task { await delete(m) } } label: {
                    Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(Theme.mut)
                        .frame(width: 30, height: 30).background(Circle().fill(Theme.bg))
                }.buttonStyle(.plain)
                Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundStyle(Theme.acc)
            }
            .padding(.vertical, 11).padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        meals = (try? await ScanAPI.shared.savedMeals()) ?? []
        loading = false
    }
    private func delete(_ m: SavedMeal) async {
        guard let id = m.id else { return }
        try? await ScanAPI.shared.deleteSavedMeal(id)
        await load()
    }
}
