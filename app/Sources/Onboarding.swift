import SwiftUI

// Local onboarding answers (held until the end, then persisted to the profile).
@Observable final class OnboardingData {
    var name: String = ""       // first name, for personalization
    var sex: String?            // male | female
    var goal: String? = ProcessInfo.processInfo.environment["STETIC_GOAL"]  // lose_fat | gain_muscle | both
    var motivation: Set<String> = [] // why they downloaded — lean, muscle, confident, event, attention, stuck
    var obstacles: Set<String> = [] // plateau, dont_know, look_same, intimidated, slow
    var focus: Set<String> = [] // arms, shoulders, chest, abs, back, legs, lower_bf
    var experience: String?     // beginner | intermediate | advanced
    var currentSplit: String = "" // their current routine (experienced lifters) — fuels split analysis
    var daysPerWeek: Int?       // 3..6
    var equipment: String?      // full_gym | home | dumbbells_only
    var equipmentItems: Set<String> = [] // shown only for home / dumbbells
    var heightCm: Double = 178
    var weightKg: Double = 80
    var goalWeightKg: Double = 75   // target bodyweight (shown only for fat-loss goals)
    var age: Int = 25
    var activity: String?       // sedentary | light | active | very_active
    var pace: String?           // slow | recommended | aggressive
    var stakes: String?         // (legacy, unused in new flow)
    var commitment: String?     // (legacy, unused in new flow)
    var timeWantedYears: Double = 3   // how long they've WANTED to change (slider) — emotional hook
    var resultsFeeling: String? // how they feel about results for time invested
    var triedPlan: String?      // ever followed a real plan/coach
    var reminders: Bool = true  // workout reminder opt-in
    var attribution: String?    // how they heard about us

    var payload: ScanAPI.ProfileInput {
        .init(sex: sex, goal: goal, motivation: Array(motivation), focus: Array(focus), experience: experience,
              currentSplit: currentSplit.trimmingCharacters(in: .whitespacesAndNewlines),
              daysPerWeek: daysPerWeek, equipment: equipment,
              heightCm: heightCm, weightKg: weightKg, age: age,
              goalWeightKg: goalWeightKg,
              activity: activity, pace: pace, attribution: attribution)
    }
}

// Sourced obstacle callbacks (no invented stats). Shown after the obstacles step.
struct ObstacleCallback { let headline: String; let body: String }
enum Callbacks {
    static let priority = ["look_same", "wasting_time", "plateau", "consistent", "dont_know", "intimidated"]
    // Stats sourced (see code-review notes): ~50% quit within 6 months; abs at 10-13% bf;
    // ~47% gym anxiety / >50% feel judged; training-to-failure helps trained lifters.
    static let map: [String: ObstacleCallback] = [
        "plateau": .init(headline: "Around half quit within 6 months.",
            body: "Usually because progress stalls. In trained lifters, taking every set to true failure is what restarts growth — not piling on volume. That's how your plan is built."),
        "look_same": .init(headline: "More effort isn't more sets.",
            body: "For trained lifters, training to failure — not just adding volume — is what separates real growth from spinning your wheels. Your plan is built around that."),
        "consistent": .init(headline: "Consistency beats intensity.",
            body: "Around half of people quit within 6 months — usually because the plan is too complicated to keep up. Yours is built to be simple enough that you actually stick to it."),
        "wasting_time": .init(headline: "More time isn't more gains.",
            body: "Junk volume just burns hours. Frequency and intensity on the right movements — not endless sets — is what builds an aesthetic frame. That's how your plan is built."),
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
    // NEW ARC: hook (feel the problem) → flip (doom → aha → fix → nutrition) →
    // stats (batched) → payoff → IDENTITY TRANSFORMATION finale. See ONBOARDING-REDESIGN.md.
    case name,
         motivation, timeWanted,
         trainingFix,                                    // "you've waited X years; it only takes 12 weeks" — off the years slider + motivation
         experience, obstacles, resultsFeeling,          // experience FIRST → obstacles branch off it (barriers vs progress-stallers)
         doom,                                           // FOMO pivot — "a year from now, the time passes anyway" — then we collect their stats
         goal,
         height, weight, goalWeight, pace,               // measurements BEFORE pace (see goal → choose speed)
         sex, days, equipment, equipmentDetail, age, activity, currentSplit,
         reminders, attribution                          // → hands off to the funnel (photo → scan → identity → paywall)

    var isInterstitial: Bool {
        switch self {
        case .doom, .trainingFix: return true
        default: return false
        }
    }

    var title: String {
        switch self {
        case .name:        return "What should we call you?"
        case .motivation:  return "Why are you really here?"
        case .timeWanted:  return "How long have you wanted this?"
        case .obstacles:   return "What's been holding you back?"
        case .experience:  return "How long have you trained?"
        case .resultsFeeling: return "And how do you feel about your results?"
        case .goal:        return "What do you want to build?"
        case .sex:         return "Which are you?"
        case .pace:        return "How fast do you want results?"
        case .currentSplit: return "What are you running now?"
        case .days:        return "How many days a week can you train?"
        case .equipment:   return "What can you train with?"
        case .equipmentDetail: return "What do you have?"
        case .height:      return "How tall are you?"
        case .weight:      return "What do you weigh?"
        case .goalWeight:  return "What's your goal weight?"
        case .age:         return "How old are you?"
        case .activity:    return "How active are you outside the gym?"
        case .attribution: return "How did you hear about us?"
        case .reminders:   return "Stay on track?"
        default: return ""
        }
    }
    var subtitle: String {
        switch self {
        case .name:       return "We'll make this feel like yours."
        case .motivation: return "Be honest — this shapes everything."
        case .timeWanted: return "How long it's been on your mind."
        case .obstacles:  return "Pick what's true. We'll target it."
        case .experience: return "Sets your starting intensity."
        case .resultsFeeling: return "Most people aren't where they hoped."
        case .goal:       return "Shapes your plan and your nutrition."
        case .sex:        return "Routes your scoring to the right rubric."
        case .pace:       return "Sets how aggressive your nutrition is."
        case .currentSplit: return "We'll analyse why it's leaving your weak points behind."
        case .days:       return "We'll build your split around your real schedule."
        case .equipment:  return "We only program what you can do."
        case .equipmentDetail: return "Pick everything you've got access to."
        case .height:      return "Used for your calorie targets."
        case .weight:      return "Used for protein and calories."
        case .goalWeight:  return "We'll set your nutrition to land you here."
        case .age:         return "Used for your calorie targets."
        case .activity:    return "Drives your daily calories."
        case .attribution: return "Helps us reach more people like you."
        case .reminders:   return "A nudge on your training days is one of the biggest drivers of staying consistent."
        default: return ""
        }
    }
}

struct Option: Identifiable {
    let id: String; let label: String; let sub: String?
    var icon: String? = nil; var tint: Color? = nil
}

enum OnbOptions {
    static let sex = [Option(id: "male", label: "Male", sub: nil),
                      Option(id: "female", label: "Female", sub: nil)]
    static let goal = [
        Option(id: "lose_fat", label: "Lose fat", sub: "Lose weight — get lean & defined",
               icon: "flame.fill", tint: Color(hex: 0xFF6B4A)),
        Option(id: "gain_muscle", label: "Build muscle", sub: "Gain weight — add lean size",
               icon: "figure.strengthtraining.traditional", tint: Theme.acc),
        Option(id: "both", label: "Recomp", sub: "Stay around your weight — lose fat & build at once",
               icon: "arrow.triangle.2.circlepath", tint: Color(hex: 0x49B6FF)),
        Option(id: "tone", label: "Tone up", sub: "Get lean & defined — stay around your weight",
               icon: "sparkles", tint: Color(hex: 0xFFC24B)),
    ]
    static let stakes = [
        Option(id: "confidence", label: "Still hiding my body", sub: nil),
        Option(id: "health", label: "My health getting worse", sub: nil),
        Option(id: "energy", label: "Stuck with low energy", sub: nil),
        Option(id: "opportunities", label: "Missing out on life", sub: nil),
    ]
    static let commitment = [
        Option(id: "all_in", label: "I'm all in", sub: "Push me — I'll show up"),
        Option(id: "committed", label: "Pretty committed", sub: "I'll give it real effort"),
        Option(id: "testing", label: "Just testing it out", sub: "Show me what this can do"),
    ]
    static let motivation = [
        Option(id: "strength", label: "Building strength", sub: "Get stronger, lift heavier over time"),
        Option(id: "muscle", label: "Muscle growth", sub: "Put on size, improve composition"),
        Option(id: "fat_loss", label: "Losing weight / fat loss", sub: "Burn calories, manage body fat"),
        Option(id: "looks", label: "Looking better", sub: "Aesthetics, confidence, feeling good"),
        Option(id: "mental", label: "Mental health", sub: "Stress relief, mood, less anxiety"),
        Option(id: "performance", label: "Athletic performance", sub: "Train for a sport or activity"),
        Option(id: "longevity", label: "Longevity & health", sub: "Stay mobile and strong as you age"),
        Option(id: "discipline", label: "Routine & discipline", sub: "Structure, accomplishment, habit"),
    ]
    static let resultsFeeling = [
        Option(id: "behind", label: "Honestly, behind where I should be", sub: nil),
        Option(id: "some", label: "Some progress — not enough", sub: nil),
        Option(id: "stuck", label: "Decent, but stuck", sub: nil),
        Option(id: "starting", label: "Just getting started", sub: nil),
    ]
    static let triedPlan = [
        Option(id: "winged", label: "Winged it / free YouTube", sub: nil),
        Option(id: "app", label: "A paid app or program", sub: nil),
        Option(id: "coach", label: "An actual coach", sub: nil),
        Option(id: "never", label: "Never had a real plan", sub: nil),
    ]
    // Shown to never-trained / beginners — barriers to getting started.
    static let obstaclesStart = [
        Option(id: "start_unknown", label: "I don't know where to start", sub: nil),
        Option(id: "intimidated", label: "Gym intimidation — feeling judged or lost", sub: nil),
        Option(id: "consistent", label: "I can't stay consistent", sub: nil),
        Option(id: "time", label: "I don't have the time", sub: nil),
        Option(id: "motivation_low", label: "Low motivation — no clear why", sub: nil),
        Option(id: "past_fail", label: "Tried before, didn't stick", sub: nil),
    ]
    // Shown to intermediate / advanced — what stalls progress once they're going.
    static let obstaclesProgress = [
        Option(id: "plateau", label: "I train hard but I'm not changing", sub: nil),
        Option(id: "no_overload", label: "Stuck on the same weights", sub: nil),
        Option(id: "no_plan", label: "No real plan — just winging it", sub: nil),
        Option(id: "nutrition", label: "My diet doesn't match my goal", sub: nil),
        Option(id: "program_hop", label: "I jump between programs", sub: nil),
        Option(id: "consistent", label: "I can't stay consistent", sub: nil),
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
        Option(id: "never", label: "Never trained", sub: "Just getting started"),
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
        Option(id: "slow", label: "Gradual", sub: "Slower — easy on your routine, but takes longer",
               icon: "tortoise.fill", tint: Color(hex: 0x8A8F98)),
        Option(id: "recommended", label: "Recommended", sub: "Fast and sustainable — what most people pick",
               icon: "bolt.fill", tint: Theme.acc),
        Option(id: "aggressive", label: "Aggressive", sub: "Fastest — demanding and harder to keep up",
               icon: "hare.fill", tint: Color(hex: 0xFF6B4A)),
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
