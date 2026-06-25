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
    var name: String
    var items: [Item] = []
    var calories: Double
    var protein_g: Double
    var carbs_g: Double
    var fat_g: Double
    var confidence: String
    var note: String?
    var servings: Double = 1

    struct Item: Codable, Identifiable, Hashable {
        var id = UUID()
        var name: String
        var portion: String?
        var calories: Double = 0
        var protein_g: Double = 0
        var carbs_g: Double = 0
        var fat_g: Double = 0
        enum CodingKeys: String, CodingKey { case name, portion, calories, protein_g, carbs_g, fat_g }
        init(name: String, portion: String? = nil, calories: Double = 0, protein_g: Double = 0, carbs_g: Double = 0, fat_g: Double = 0) {
            self.name = name; self.portion = portion; self.calories = calories
            self.protein_g = protein_g; self.carbs_g = carbs_g; self.fat_g = fat_g
        }
        init(from d: Decoder) throws {   // macros optional so it survives an older meal-scan response
            let c = try d.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            portion = try c.decodeIfPresent(String.self, forKey: .portion)
            calories = try c.decodeIfPresent(Double.self, forKey: .calories) ?? 0
            protein_g = try c.decodeIfPresent(Double.self, forKey: .protein_g) ?? 0
            carbs_g = try c.decodeIfPresent(Double.self, forKey: .carbs_g) ?? 0
            fat_g = try c.decodeIfPresent(Double.self, forKey: .fat_g) ?? 0
        }
    }

    // Totals derive from items when they carry macros; otherwise fall back to the model's totals.
    private func sum(_ kp: (Item) -> Double) -> Double { items.reduce(0) { $0 + kp($1) } }
    var baseCalories: Double { sum(\.calories) > 0 ? sum(\.calories) : calories }
    var baseProtein: Double  { sum(\.calories) > 0 ? sum(\.protein_g) : protein_g }
    var baseCarbs: Double    { sum(\.calories) > 0 ? sum(\.carbs_g) : carbs_g }
    var baseFat: Double      { sum(\.calories) > 0 ? sum(\.fat_g) : fat_g }
    var shownCalories: Double { (baseCalories * servings).rounded() }
    var shownProtein: Double  { (baseProtein * servings).rounded() }
    var shownCarbs: Double    { (baseCarbs * servings).rounded() }
    var shownFat: Double      { (baseFat * servings).rounded() }

    enum CodingKeys: String, CodingKey { case name, items, calories, protein_g, carbs_g, fat_g, confidence, note }
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

// A bodyweight entry.
struct WeightPoint: Codable, Identifiable {
    var id = UUID()
    let weight_kg: Double
    let logged_at: String
    enum CodingKeys: String, CodingKey { case weight_kg, logged_at }
    var date: Date {
        let a = ISO8601DateFormatter(); a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = a.date(from: logged_at) { return d }
        let b = ISO8601DateFormatter(); b.formatOptions = [.withInternetDateTime]
        return b.date(from: logged_at) ?? Date()
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
