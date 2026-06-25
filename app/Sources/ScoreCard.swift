import SwiftUI

// Matches the /scan edge function response (scans row shape).
struct ScoreCard: Codable, Identifiable {
    var id: String = UUID().uuidString
    let aesthetic_score: Double          // 0.0–10.0
    let rank_tier: String                // enum string e.g. "greek_god"
    let body_fat: Double
    let symmetry: Double
    let potential: Double
    let muscles: [Muscle]
    let verdict: String
    var size_flag: String? = nil
    var estimated: Bool = false

    struct Muscle: Codable, Identifiable {
        var id: String { group }
        let group: String
        let score: Double
        let visible: Bool
        let note: String
    }

    enum CodingKeys: String, CodingKey {
        case aesthetic_score, rank_tier, body_fat, symmetry, potential, muscles, verdict, size_flag, estimated
    }
}

extension ScoreCard {
    var tier: Tier { Tier(rawValue: rank_tier) ?? .bronze }

    /// Muscles already ranked strongest → weakest (server sorts, but be safe).
    var rankedMuscles: [Muscle] { muscles.sorted { $0.score > $1.score } }

    /// Lower-bound score for each tier, in ladder order.
    static let tierFloors: [(Tier, Double)] = [
        (.bronze, 0), (.silver, 4), (.gold, 5), (.platinum, 6),
        (.diamond, 7), (.elite, 8), (.mythic, 8.8), (.greek_god, 9.3),
    ]

    var tierIndex: Int { Tier.allCases.firstIndex(of: tier) ?? 0 }

    /// (nextTier, pointsToGo) or nil at apex.
    var nextTier: (Tier, Double)? {
        let floors = ScoreCard.tierFloors
        guard tierIndex + 1 < floors.count else { return nil }
        let (next, floor) = floors[tierIndex + 1]
        return (next, max(0, (floor - aesthetic_score)))
    }

    /// Rough estimate of how long to reach potential with focused training.
    var potentialTimeframe: String {
        let gap = max(0, potential - aesthetic_score)
        let weeks = max(4, Int((gap * 16).rounded()))   // ~1 point ≈ 4 months
        if weeks <= 14 { return "≈ \(weeks) weeks" }
        return "≈ \(Int((Double(weeks) / 4.3).rounded())) months"
    }

    /// Display color for a muscle bar/value by absolute score.
    static func muscleColor(_ score: Double) -> Color {
        if score >= 8.5 { return Theme.acc }
        if score >= 6.5 { return Theme.amber }
        return Theme.red
    }
}

extension Tier {
    /// Single source of truth for score → tier (matches the server ladder).
    static func forScore(_ s10: Double) -> Tier {
        if s10 >= 9.3 { return .greek_god }
        if s10 >= 8.8 { return .mythic }
        if s10 >= 8.0 { return .elite }
        if s10 >= 7.0 { return .diamond }
        if s10 >= 6.0 { return .platinum }
        if s10 >= 5.0 { return .gold }
        if s10 >= 4.0 { return .silver }
        return .bronze
    }
    var icon: String {
        switch self {
        case .bronze:    return "shield.fill"
        case .silver:    return "shield.lefthalf.filled"
        case .gold:      return "rosette"
        case .platinum:  return "diamond.fill"
        case .diamond:   return "diamond.fill"
        case .elite:     return "bolt.fill"
        case .mythic:    return "flame.fill"
        case .greek_god: return "crown.fill"
        }
    }
}

// Sample data for previews / UI dev.
extension ScoreCard {
    static let sample = ScoreCard(
        aesthetic_score: 6.4,
        rank_tier: "platinum",
        body_fat: 15,
        symmetry: 8.6,
        potential: 8.8,
        muscles: [
            .init(group: "chest", score: 7.8, visible: true, note: "Solid fullness"),
            .init(group: "arms", score: 7.0, visible: true, note: "Good definition"),
            .init(group: "shoulders", score: 6.2, visible: true, note: "Needs width"),
            .init(group: "legs", score: 6.0, visible: false, note: "Estimated"),
            .init(group: "abs", score: 5.8, visible: true, note: "Some definition"),
            .init(group: "back", score: 4.8, visible: false, note: "Flat, lagging"),
        ],
        verdict: "Solid chest, but a flat back is capping your whole frame. Fix the lats and you jump a full tier."
    )
}
