import Foundation

// Matches the /plan edge function `content` payload.
struct PlanContent: Codable {
    let goal_label: String
    let summary: String
    let macros: Macros
    let weekly_split: [Day]
    let priorities: [Priority]
    let muscle_breakdown: [Breakdown]
    let projection: Projection
    var split_critique: String?

    struct Projection: Codable {
        let milestones: [Milestone]
        struct Milestone: Codable, Identifiable {
            var id: Int { weeks }
            let weeks: Int
            let projected_score: Double
            let projected_tier: String
            let points_gain: Double
            var projected_body_fat: Double?
            let summary: String
            let muscle_gains: [Gain]
            struct Gain: Codable, Identifiable {
                var id: String { group }
                let group: String
                let from: Double
                let to: Double
            }
        }
    }

    struct Macros: Codable {
        let calories: Double
        let protein_g: Double
        let carbs_g: Double
        let fat_g: Double
        let rationale: String
    }
    struct Day: Codable, Identifiable {
        var id: String { day }
        let day: String
        let focus: String
        let exercises: [Exercise]
    }
    struct Exercise: Codable, Identifiable {
        var id: String { name }
        let name: String
        let sets: Int
        let reps: String
        let target: String
        var note: String?
    }
    struct Priority: Codable, Identifiable {
        var id: String { area }
        let area: String
        let why: String
        let action: String
    }
    struct Breakdown: Codable, Identifiable {
        var id: String { group }
        let group: String
        let rating: Double
        let detail: String
        let sub: [Sub]
        struct Sub: Codable, Identifiable {
            var id: String { name }
            let name: String
            let status: String
            let cue: String
        }
    }
}
