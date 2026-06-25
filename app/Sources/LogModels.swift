import Foundation

// One logged set the user actually performed.
struct LoggedSet: Codable, Identifiable, Hashable {
    var id = UUID()
    var weight: Double = 0
    var reps: Int = 0
    var done: Bool = false

    enum CodingKeys: String, CodingKey { case weight, reps, done }
}

// One exercise within a logged session.
struct LoggedExercise: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var target: String
    var sets: [LoggedSet]

    enum CodingKeys: String, CodingKey { case name, target, sets }
}

// A completed (or in-progress) training session.
struct WorkoutLog: Codable, Identifiable {
    var id: String?
    var log_date: String?
    var day_label: String?
    var exercises: [LoggedExercise]
}

// A logged meal — only derived numbers, never the photo.
struct MealLog: Codable, Identifiable {
    var id: String?
    var log_date: String?
    var name: String
    var calories: Double
    var protein_g: Double
    var carbs_g: Double
    var fat_g: Double
}

// What /meal-scan returns before the user confirms and saves it.
struct MealEstimate: Codable, Identifiable {
    var id = UUID()
    let name: String
    let calories: Double
    let protein_g: Double
    let carbs_g: Double
    let fat_g: Double
    let confidence: String
    var note: String?

    enum CodingKeys: String, CodingKey { case name, calories, protein_g, carbs_g, fat_g, confidence, note }
}

// A single scan reduced to its plottable numbers (for the progress chart).
struct ScanPoint: Codable, Identifiable {
    var id = UUID()
    let aesthetic_score: Double
    var body_fat: Double?
    var potential: Double?
    let rank_tier: String
    let created_at: String

    enum CodingKeys: String, CodingKey { case aesthetic_score, body_fat, potential, rank_tier, created_at }

    var date: Date {
        let a = ISO8601DateFormatter(); a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = a.date(from: created_at) { return d }
        let b = ISO8601DateFormatter(); b.formatOptions = [.withInternetDateTime]
        return b.date(from: created_at) ?? Date()
    }
}

enum LogDate {
    static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func string(_ d: Date) -> String { fmt.string(from: d) }
    static var today: String { string(Date()) }
}

// Consecutive-day training streak ending today or yesterday.
enum Streak {
    static func count(from dateStrings: [String]) -> Int {
        let cal = Calendar.current
        let days = Set(dateStrings.compactMap { LogDate.fmt.date(from: $0) }.map { cal.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }
        var cursor = cal.startOfDay(for: Date())
        // Allow the streak to be "alive" if they trained today OR yesterday.
        if !days.contains(cursor) {
            guard let y = cal.date(byAdding: .day, value: -1, to: cursor), days.contains(y) else { return 0 }
            cursor = y
        }
        var n = 0
        while days.contains(cursor) {
            n += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return n
    }
}
