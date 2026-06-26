import SwiftUI

// Curated high-protein meal ideas, grouped by meal. One tap logs it to today.
struct SampleMeal: Identifiable {
    let id = UUID()
    let name: String
    let type: MealType
    let calories, protein, carbs, fat: Double
    var asMeal: MealEstimate {
        MealEstimate(name: name, calories: calories, protein_g: protein, carbs_g: carbs, fat_g: fat, confidence: "sample")
    }
}

enum SampleMeals {
    static let all: [SampleMeal] = [
        // breakfast
        .init(name: "Greek yogurt, berries & granola", type: .breakfast, calories: 380, protein: 30, carbs: 45, fat: 8),
        .init(name: "3-egg omelette & spinach", type: .breakfast, calories: 320, protein: 24, carbs: 4, fat: 22),
        .init(name: "Protein oats & banana", type: .breakfast, calories: 420, protein: 30, carbs: 58, fat: 8),
        .init(name: "Egg whites, turkey bacon & toast", type: .breakfast, calories: 350, protein: 35, carbs: 30, fat: 9),
        // lunch
        .init(name: "Chicken, rice & broccoli", type: .lunch, calories: 600, protein: 50, carbs: 62, fat: 14),
        .init(name: "Tuna & avocado wrap", type: .lunch, calories: 480, protein: 38, carbs: 40, fat: 18),
        .init(name: "Steak salad bowl", type: .lunch, calories: 520, protein: 45, carbs: 20, fat: 28),
        .init(name: "Turkey & quinoa bowl", type: .lunch, calories: 540, protein: 42, carbs: 55, fat: 15),
        // dinner
        .init(name: "Salmon, sweet potato & asparagus", type: .dinner, calories: 620, protein: 45, carbs: 45, fat: 28),
        .init(name: "Lean beef stir-fry & rice", type: .dinner, calories: 650, protein: 48, carbs: 60, fat: 22),
        .init(name: "Grilled chicken pasta", type: .dinner, calories: 600, protein: 45, carbs: 65, fat: 16),
        .init(name: "Shrimp & veggie bowl", type: .dinner, calories: 480, protein: 40, carbs: 45, fat: 14),
        // snacks
        .init(name: "Protein shake", type: .snacks, calories: 200, protein: 40, carbs: 6, fat: 2),
        .init(name: "Cottage cheese & pineapple", type: .snacks, calories: 220, protein: 25, carbs: 18, fat: 5),
        .init(name: "Apple & peanut butter", type: .snacks, calories: 270, protein: 8, carbs: 30, fat: 14),
        .init(name: "Beef jerky & almonds", type: .snacks, calories: 300, protein: 25, carbs: 10, fat: 18),
    ]
}

struct MealIdeasView: View {
    var onLog: (SampleMeal) -> Void
    var onCraving: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ideas & cravings").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                        .padding(8).background(Circle().fill(Theme.card))
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button { onCraving() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "wand.and.stars").font(.system(size: 16, weight: .bold))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Craving something?").font(.system(size: 15, weight: .heavy))
                                Text("Get an AI fix that still fits your day").font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
                        }
                        .foregroundStyle(Theme.acc)
                        .padding(14).frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.acc.opacity(0.10)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.acc.opacity(0.4), lineWidth: 1)))
                    }
                    Text("MEAL IDEAS").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
                    ForEach(MealType.allCases) { type in
                        let meals = SampleMeals.all.filter { $0.type == type }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: type.icon).font(.system(size: 12)).foregroundStyle(Theme.acc)
                                Text(type.label.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
                            }
                            ForEach(meals) { meal in row(meal) }
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func row(_ meal: SampleMeal) -> some View {
        Button { onLog(meal); dismiss() } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(meal.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    Text("\(Int(meal.calories)) cal · P \(Int(meal.protein)) · C \(Int(meal.carbs)) · F \(Int(meal.fat))")
                        .font(.system(size: 11)).foregroundStyle(Theme.mut)
                }
                Spacer()
                Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundStyle(Theme.acc)
            }
            .padding(.vertical, 11).padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }
}
