import SwiftUI

// Local onboarding answers (held until the end, then persisted to the profile).
@Observable final class OnboardingData {
    var name: String = ""       // first name, for personalization
    var sex: String?            // male | female
    var goal: String?           // lose_fat | gain_muscle | both
    var focus: Set<String> = [] // arms, shoulders, chest, abs, back, legs, lower_bf
    var experience: String?     // beginner | intermediate | advanced
    var daysPerWeek: Int?       // 3..6
    var equipment: String?      // full_gym | home | dumbbells_only
    var heightCm: Double = 178
    var weightKg: Double = 80
    var age: Int = 25

    var payload: ScanAPI.ProfileInput {
        .init(sex: sex, goal: goal, focus: Array(focus), experience: experience,
              daysPerWeek: daysPerWeek, equipment: equipment,
              heightCm: heightCm, weightKg: weightKg, age: age)
    }
}

enum OnbStep: Int, CaseIterable {
    case name, sex, goal, focus, experience, days, equipment, height, weight, age

    var title: String {
        switch self {
        case .name:       return "What should we call you?"
        case .sex:        return "Which are you?"
        case .goal:       return "What's your goal?"
        case .focus:      return "What do you want to bring up?"
        case .experience: return "How long have you trained?"
        case .days:       return "Days per week?"
        case .equipment:  return "What can you train with?"
        case .height:     return "How tall are you?"
        case .weight:     return "What do you weigh?"
        case .age:        return "How old are you?"
        }
    }
    var subtitle: String {
        switch self {
        case .name:       return "We'll make your plan feel like yours."
        case .sex:        return "Routes your scoring to the right rubric."
        case .goal:       return "Shapes your plan and macros."
        case .focus:      return "Optional — pick any to prioritize. Your scan finds the rest."
        case .experience: return "Sets your starting intensity."
        case .days:       return "We build around your real schedule."
        case .equipment:  return "We only program what you can do."
        case .height:     return "Used for your calorie targets."
        case .weight:     return "Used for protein and calories."
        case .age:        return "Used for your calorie targets."
        }
    }
}

struct Option: Identifiable { let id: String; let label: String; let sub: String? }

enum OnbOptions {
    static let sex = [Option(id: "male", label: "Male", sub: nil),
                      Option(id: "female", label: "Female", sub: nil)]
    static let goal = [
        Option(id: "lose_fat", label: "Lose fat", sub: "Get lean and defined"),
        Option(id: "gain_muscle", label: "Build muscle", sub: "Add size where it counts"),
        Option(id: "both", label: "Both / recomp", sub: "Lean out and build"),
    ]
    static let focus = [
        Option(id: "shoulders", label: "Shoulders", sub: nil),
        Option(id: "chest", label: "Chest", sub: nil),
        Option(id: "back", label: "Back", sub: nil),
        Option(id: "arms", label: "Arms", sub: nil),
        Option(id: "abs", label: "Abs", sub: nil),
        Option(id: "legs", label: "Legs", sub: nil),
        Option(id: "lower_bf", label: "Lower body fat", sub: nil),
    ]
    static let experience = [
        Option(id: "beginner", label: "Beginner", sub: "Under a year"),
        Option(id: "intermediate", label: "Intermediate", sub: "1–3 years"),
        Option(id: "advanced", label: "Advanced", sub: "3+ years"),
    ]
    static let days = [
        Option(id: "3", label: "3 days", sub: nil),
        Option(id: "4", label: "4 days", sub: nil),
        Option(id: "5", label: "5 days", sub: nil),
        Option(id: "6", label: "6 days", sub: nil),
    ]
    static let equipment = [
        Option(id: "full_gym", label: "Full gym", sub: "Machines, barbells, cables"),
        Option(id: "home", label: "Home gym", sub: "Some equipment"),
        Option(id: "dumbbells_only", label: "Dumbbells only", sub: "Minimal kit"),
    ]
}
