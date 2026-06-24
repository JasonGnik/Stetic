import SwiftUI

// Local onboarding answers (held until the end, then persisted to the profile).
@Observable final class OnboardingData {
    var name: String = ""       // first name, for personalization
    var sex: String?            // male | female
    var goal: String? = ProcessInfo.processInfo.environment["STETIC_GOAL"]  // lose_fat | gain_muscle | both
    var obstacles: Set<String> = [] // plateau, dont_know, look_same, intimidated, slow
    var focus: Set<String> = [] // arms, shoulders, chest, abs, back, legs, lower_bf
    var experience: String?     // beginner | intermediate | advanced
    var daysPerWeek: Int?       // 3..6
    var equipment: String?      // full_gym | home | dumbbells_only
    var equipmentItems: Set<String> = [] // shown only for home / dumbbells
    var heightCm: Double = 178
    var weightKg: Double = 80
    var goalWeightKg: Double = 75   // target bodyweight (shown only for fat-loss goals)
    var age: Int = 25
    var activity: String?       // sedentary | light | active | very_active
    var pace: String?           // slow | recommended | aggressive
    var reminders: Bool = true  // workout reminder opt-in
    var attribution: String?    // how they heard about us

    // Goal weight only matters when there's a weight target to hit.
    var usesGoalWeight: Bool { goal == "lose_fat" || goal == "both" }

    var payload: ScanAPI.ProfileInput {
        .init(sex: sex, goal: goal, focus: Array(focus), experience: experience,
              daysPerWeek: daysPerWeek, equipment: equipment,
              heightCm: heightCm, weightKg: weightKg, age: age,
              goalWeightKg: usesGoalWeight ? goalWeightKg : nil,
              activity: activity, pace: pace, attribution: attribution)
    }
}

// Sourced obstacle callbacks (no invented stats). Shown after the obstacles step.
struct ObstacleCallback { let headline: String; let body: String }
enum Callbacks {
    static let priority = ["plateau", "look_same", "slow", "dont_know", "intimidated"]
    // Stats sourced (see code-review notes): ~50% quit within 6 months; abs at 10-13% bf;
    // ~47% gym anxiety / >50% feel judged; training-to-failure helps trained lifters.
    static let map: [String: ObstacleCallback] = [
        "plateau": .init(headline: "Around half quit within 6 months.",
            body: "Usually because progress stalls. In trained lifters, taking every set to true failure is what restarts growth — not piling on volume. That's how your plan is built."),
        "look_same": .init(headline: "More effort isn't more sets.",
            body: "For trained lifters, training to failure — not just adding volume — is what separates real growth from spinning your wheels. Your plan is built around that."),
        "slow": .init(headline: "Slow results = the wrong plan.",
            body: "Around half of people quit within 6 months because progress stalls. The fix isn't more time in the gym — it's a plan built around your body and your goal. That's exactly what you'll get."),
        "dont_know": .init(headline: "Most physiques are capped by 1–2 weak points.",
            body: "A single lagging group can break your whole line. Stetic pinpoints yours and builds the plan around fixing it."),
        "intimidated": .init(headline: "Nearly half of people feel it too.",
            body: "About 47% feel anxious at the gym and over half feel judged for their form. Every session here tells you exactly what to do — no guessing."),
    ]
    static func pick(_ obstacles: Set<String>) -> ObstacleCallback {
        for id in priority where obstacles.contains(id) { return map[id]! }
        return map["dont_know"]!
    }
}

enum OnbStep: Int, CaseIterable {
    case name, sex, goal, pace, obstacles, callback, experience, days, equipment,
         equipmentDetail, height, weight, goalWeight, age, activity, socialProof,
         attribution, reminders

    var isInterstitial: Bool { self == .callback || self == .socialProof }

    var title: String {
        switch self {
        case .name:        return "What should we call you?"
        case .sex:         return "Which are you?"
        case .goal:        return "What's your goal?"
        case .pace:        return "How fast do you want results?"
        case .obstacles:   return "What's holding you back?"
        case .experience:  return "How long have you trained?"
        case .days:        return "Days per week?"
        case .equipment:   return "What can you train with?"
        case .equipmentDetail: return "What do you have?"
        case .height:      return "How tall are you?"
        case .weight:      return "What do you weigh?"
        case .goalWeight:  return "What's your goal weight?"
        case .age:         return "How old are you?"
        case .activity:    return "How active are you?"
        case .attribution: return "How did you hear about us?"
        case .reminders:   return "Stay on track?"
        case .callback, .socialProof: return ""
        }
    }
    var subtitle: String {
        switch self {
        case .name:       return "We'll make your plan feel like yours."
        case .sex:        return "Routes your scoring to the right rubric."
        case .goal:       return "Shapes your plan and nutrition."
        case .pace:       return "Sets how aggressive your nutrition is."
        case .obstacles:  return "Pick any that apply — we'll target them."
        case .experience: return "Sets your starting intensity."
        case .days:       return "We build around your real schedule."
        case .equipment:  return "We only program what you can do."
        case .equipmentDetail: return "Pick everything you've got access to."
        case .height:      return "Used for your calorie targets."
        case .weight:      return "Used for protein and calories."
        case .goalWeight:  return "We'll set your nutrition to land you here."
        case .age:         return "Used for your calorie targets."
        case .activity:    return "Outside the gym — drives your calories."
        case .attribution: return "Helps us reach more people like you."
        case .reminders:   return "A nudge on training days keeps you consistent."
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
    static let days = (1...7).map { Option(id: "\($0)", label: $0 == 1 ? "1 day" : "\($0) days", sub: nil) }
    static let equipment = [
        Option(id: "full_gym", label: "Full gym", sub: "Machines, barbells, cables"),
        Option(id: "home", label: "Home gym", sub: "Your own setup"),
        Option(id: "bodyweight", label: "Bodyweight only", sub: "No equipment"),
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
    static let pace = [
        Option(id: "slow", label: "Steady & sustainable", sub: "Slower, easier to stick to"),
        Option(id: "recommended", label: "Recommended", sub: "Balanced — most people"),
        Option(id: "aggressive", label: "Aggressive", sub: "Faster, more demanding"),
    ]
    static let activity = [
        Option(id: "sedentary", label: "Sedentary", sub: "Desk job, little walking"),
        Option(id: "light", label: "Lightly active", sub: "Some walking daily"),
        Option(id: "active", label: "Active", sub: "On your feet a lot"),
        Option(id: "very_active", label: "Very active", sub: "Physical job or daily cardio"),
    ]
    static let reminders = [
        Option(id: "yes", label: "Yes, remind me", sub: "A nudge on training days"),
        Option(id: "no", label: "Not now", sub: "You can turn these on later"),
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
