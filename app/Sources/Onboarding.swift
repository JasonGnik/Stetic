import SwiftUI

// Local onboarding answers (held until the end, then persisted to the profile).
@Observable final class OnboardingData {
    var name: String = ""       // first name, for personalization
    var sex: String?            // male | female
    var goal: String?           // lose_fat | gain_muscle | both
    var obstacles: Set<String> = [] // plateau, dont_know, look_same, intimidated, slow
    var focus: Set<String> = [] // arms, shoulders, chest, abs, back, legs, lower_bf
    var experience: String?     // beginner | intermediate | advanced
    var daysPerWeek: Int?       // 3..6
    var equipment: String?      // full_gym | home | dumbbells_only
    var equipmentItems: Set<String> = [] // shown only for home / dumbbells
    var heightCm: Double = 178
    var weightKg: Double = 80
    var age: Int = 25
    var attribution: String?    // how they heard about us

    var payload: ScanAPI.ProfileInput {
        .init(sex: sex, goal: goal, focus: Array(focus), experience: experience,
              daysPerWeek: daysPerWeek, equipment: equipment,
              heightCm: heightCm, weightKg: weightKg, age: age, attribution: attribution)
    }
}

// Sourced obstacle callbacks (no invented stats). Shown after the obstacles step.
struct ObstacleCallback { let headline: String; let body: String }
enum Callbacks {
    static let priority = ["plateau", "look_same", "slow", "dont_know", "intimidated"]
    static let map: [String: ObstacleCallback] = [
        "plateau": .init(headline: "Plateaus aren't fixed with more sets.",
            body: "In trained lifters, taking each set to true failure is what forces new growth — not piling on volume. Your plan is built on exactly that."),
        "look_same": .init(headline: "Hard work without intensity stalls.",
            body: "Research on trained lifters shows effort to failure — not just more time in the gym — is what separates real growth from spinning your wheels."),
        "slow": .init(headline: "Leanness is your fastest lever.",
            body: "For most men, abs appear around 10–13% body fat. Getting lean is the most visible, most controllable change — and your plan prioritizes it."),
        "dont_know": .init(headline: "Most physiques are capped by 1–2 weak points.",
            body: "A single lagging group can break your whole line. Stetic pinpoints yours and builds the plan around fixing it."),
        "intimidated": .init(headline: "No more guessing on the gym floor.",
            body: "Every session is mapped to your level and your weak points — you'll walk in knowing exactly what to do."),
    ]
    static func pick(_ obstacles: Set<String>) -> ObstacleCallback {
        for id in priority where obstacles.contains(id) { return map[id]! }
        return map["dont_know"]!
    }
}

enum OnbStep: Int, CaseIterable {
    case name, sex, goal, obstacles, callback, experience, days, equipment,
         equipmentDetail, height, weight, age, socialProof, attribution

    var isInterstitial: Bool { self == .callback || self == .socialProof }

    var title: String {
        switch self {
        case .name:        return "What should we call you?"
        case .sex:         return "Which are you?"
        case .goal:        return "What's your goal?"
        case .obstacles:   return "What's holding you back?"
        case .experience:  return "How long have you trained?"
        case .days:        return "Days per week?"
        case .equipment:   return "What can you train with?"
        case .equipmentDetail: return "What do you have?"
        case .height:      return "How tall are you?"
        case .weight:      return "What do you weigh?"
        case .age:         return "How old are you?"
        case .attribution: return "How did you hear about us?"
        case .callback, .socialProof: return ""
        }
    }
    var subtitle: String {
        switch self {
        case .name:       return "We'll make your plan feel like yours."
        case .sex:        return "Routes your scoring to the right rubric."
        case .goal:       return "Shapes your plan and macros."
        case .obstacles:  return "Pick any that apply — we'll target them."
        case .experience: return "Sets your starting intensity."
        case .days:       return "We build around your real schedule."
        case .equipment:  return "We only program what you can do."
        case .equipmentDetail: return "Pick everything you've got access to."
        case .height:      return "Used for your calorie targets."
        case .weight:      return "Used for protein and calories."
        case .age:         return "Used for your calorie targets."
        case .attribution: return "Helps us reach more people like you."
        case .callback, .socialProof: return ""
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
    static let obstacles = [
        Option(id: "plateau", label: "I've plateaued", sub: nil),
        Option(id: "dont_know", label: "I don't know what to train", sub: nil),
        Option(id: "look_same", label: "I train hard but look the same", sub: nil),
        Option(id: "intimidated", label: "Intimidated in the gym", sub: nil),
        Option(id: "slow", label: "Results are too slow", sub: nil),
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
    static let equipmentItems = [
        Option(id: "dumbbells", label: "Dumbbells", sub: nil),
        Option(id: "barbell", label: "Barbell + plates", sub: nil),
        Option(id: "bench", label: "Bench", sub: nil),
        Option(id: "rack", label: "Squat rack", sub: nil),
        Option(id: "pullup", label: "Pull-up bar", sub: nil),
        Option(id: "cables", label: "Cable / machine", sub: nil),
        Option(id: "kettlebell", label: "Kettlebells", sub: nil),
        Option(id: "bands", label: "Resistance bands", sub: nil),
    ]
    static let attribution = [
        Option(id: "tiktok", label: "TikTok", sub: nil),
        Option(id: "instagram", label: "Instagram", sub: nil),
        Option(id: "youtube", label: "YouTube", sub: nil),
        Option(id: "app_store", label: "App Store", sub: nil),
        Option(id: "friend", label: "A friend", sub: nil),
        Option(id: "other", label: "Other", sub: nil),
    ]
}
