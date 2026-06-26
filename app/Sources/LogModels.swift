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
    var repRange: String?      // e.g. "5-9" — what we're working towards (optional: older logs lack it)
    var sets: [LoggedSet]

    enum CodingKeys: String, CodingKey { case name, target, repRange, sets }
}

// Deload cadence — JP doctrine: pull back roughly every 8 weeks.
enum Deload {
    static let cycleWeeks = 8
    // Weeks since the anchor (an explicit reset date, else the earliest training date).
    static func weeks(anchor: String, earliest: String?) -> Int {
        let start = anchor.isEmpty ? (earliest ?? "") : anchor
        guard let d = LogDate.fmt.date(from: start) else { return 0 }
        return (Calendar.current.dateComponents([.day], from: d, to: AppClock.now).day ?? 0) / 7
    }
    static func isDue(_ weeks: Int) -> Bool { weeks >= cycleWeeks }
    // The smallest sensible jump when you earn a weight increase.
    static func increment(for weight: Double) -> Double { weight >= 30 ? 5 : 2.5 }
    static func round5(_ w: Double) -> Double { (w / 5).rounded() * 5 }
}

// A rep target like "5-9" parsed into its low/high bounds, for progressive-overload cues.
struct RepRange {
    let low: Int
    let high: Int
    init?(_ raw: String?) {
        guard let raw, !raw.isEmpty else { return nil }
        let nums = raw.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard let first = nums.first else { return nil }
        low = first
        high = nums.count > 1 ? max(first, nums[1]) : first
    }
    var label: String { low == high ? "\(low)" : "\(low)–\(high)" }
    func contains(_ reps: Int) -> Bool { reps >= low && reps <= high }

    // Parse a multi-range reps string ("5-9, 10-12, 15-20") into one range PER SET:
    // set 0 = the heavy top set, set 1 = the back-off, etc. The last listed range
    // repeats if there are more sets than ranges. JP prescribes different targets for
    // the top vs back-off set, so each set must be judged against its own range
    // (the old single-range parse silently dropped everything after the first).
    static func perSet(_ raw: String?, count: Int) -> [RepRange?] {
        guard count > 0 else { return [] }
        let ranges = (raw ?? "").split(separator: ",").compactMap { RepRange(String($0)) }
        guard let last = ranges.last else { return Array(repeating: nil, count: count) }
        return (0..<count).map { ranges.indices.contains($0) ? ranges[$0] : last }
    }
}

// A completed (or in-progress) training session.
struct WorkoutLog: Codable, Identifiable {
    var id: String?
    var log_date: String?
    var day_label: String?
    var exercises: [LoggedExercise]
}

// A logged meal — the foods that make it up + derived totals, never the photo.
struct MealLog: Codable, Identifiable {
    var id: String?
    var log_date: String?
    var name: String
    var calories: Double
    var protein_g: Double
    var carbs_g: Double
    var fat_g: Double
    var meal_type: String?
    var items: [MealEstimate.Item]?     // the component foods (optional: older rows lack it)
    var foods: [MealEstimate.Item] { items ?? [] }
    // An editable estimate built from this logged meal.
    var asEstimate: MealEstimate {
        var m = MealEstimate(name: name, items: foods, calories: calories, protein_g: protein_g, carbs_g: carbs_g, fat_g: fat_g, confidence: "logged")
        return m
    }
}

// Breakfast / lunch / dinner / snacks — how the day's food is grouped.
enum MealType: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snacks
    var id: String { rawValue }
    var label: String {
        switch self {
        case .breakfast: return "Breakfast"; case .lunch: return "Lunch"
        case .dinner: return "Dinner"; case .snacks: return "Snacks"
        }
    }
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"; case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"; case .snacks: return "carrot.fill"
        }
    }
    // Map any stored value (incl. legacy "other") to a bucket for display.
    static func bucket(_ raw: String?) -> MealType {
        MealType(rawValue: raw ?? "") ?? .snacks
    }
    // Sensible default based on time of day.
    static func current() -> MealType {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<18: return .snacks
        default: return .dinner
        }
    }
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
        var calories: Double = 0      // TOTAL for the current quantity/unit (not per-unit)
        var protein_g: Double = 0
        var carbs_g: Double = 0
        var fat_g: Double = 0
        var quantity: Double = 1      // how much of `unit` this food is
        var unit: String = "serving"  // serving | g | oz | cup | tbsp | piece | ml
        enum CodingKeys: String, CodingKey { case name, portion, calories, protein_g, carbs_g, fat_g, quantity, unit }
        init(name: String, portion: String? = nil, calories: Double = 0, protein_g: Double = 0, carbs_g: Double = 0, fat_g: Double = 0, quantity: Double = 1, unit: String = "serving") {
            self.name = name; self.portion = portion; self.calories = calories
            self.protein_g = protein_g; self.carbs_g = carbs_g; self.fat_g = fat_g
            self.quantity = quantity; self.unit = unit
        }
        init(from d: Decoder) throws {   // fields optional so it survives older rows / responses
            let c = try d.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            portion = try c.decodeIfPresent(String.self, forKey: .portion)
            calories = try c.decodeIfPresent(Double.self, forKey: .calories) ?? 0
            protein_g = try c.decodeIfPresent(Double.self, forKey: .protein_g) ?? 0
            carbs_g = try c.decodeIfPresent(Double.self, forKey: .carbs_g) ?? 0
            fat_g = try c.decodeIfPresent(Double.self, forKey: .fat_g) ?? 0
            quantity = try c.decodeIfPresent(Double.self, forKey: .quantity) ?? 1
            unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? "serving"
        }

        // Best-effort parse of a free-text portion (e.g. "~150g", "1 cup") into qty + unit.
        static func parsePortion(_ s: String?) -> (Double, String) {
            guard let s = s?.lowercased() else { return (1, "serving") }
            let num = s.split(whereSeparator: { !"0123456789.".contains($0) }).compactMap { Double($0) }.first ?? 1
            let unit: String
            if s.contains("oz") { unit = "oz" } else if s.contains("ml") { unit = "ml" }
            else if s.contains("g") { unit = "g" } else if s.contains("cup") { unit = "cup" }
            else if s.contains("tbsp") { unit = "tbsp" } else if s.contains("piece") || s.contains("slice") { unit = "piece" }
            else { unit = "serving" }
            return (num, unit)
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

// An AI "craving fix" result tuned to how badly they want it.
struct CravingResult: Codable, Identifiable {
    var id = UUID()
    var name: String
    var version: String = ""
    var portion: String = ""
    var calories: Double = 0
    var protein_g: Double = 0
    var carbs_g: Double = 0
    var fat_g: Double = 0
    var ingredients: [String] = []
    var fits_today: Bool = true
    var verdict: String = ""
    var fit_tip: String = ""
    var adjustments: [String] = []
    var tomorrow_plan: [String] = []
    enum CodingKeys: String, CodingKey { case name, version, portion, calories, protein_g, carbs_g, fat_g, ingredients, fits_today, verdict, fit_tip, adjustments, tomorrow_plan }
    var asMeal: MealEstimate {
        MealEstimate(name: name, calories: calories, protein_g: protein_g, carbs_g: carbs_g, fat_g: fat_g, confidence: "craving")
    }
}

// A saved meal — a named combo of foods the user can re-log in one tap.
struct SavedMeal: Codable, Identifiable {
    var id: String?
    var name: String
    var items: [MealEstimate.Item] = []
    var calories: Double = 0
    var protein_g: Double = 0
    var carbs_g: Double = 0
    var fat_g: Double = 0
    enum CodingKeys: String, CodingKey { case id, name, items, calories, protein_g, carbs_g, fat_g }
    var asEstimate: MealEstimate {
        MealEstimate(name: name, items: items, calories: calories, protein_g: protein_g, carbs_g: carbs_g, fat_g: fat_g, confidence: "saved")
    }
}

// A food catalog hit from /food-search (macros per the stated portion, ~100g).
struct FoodHit: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var brand: String = ""
    var portion: String = ""
    var calories: Double = 0
    var protein_g: Double = 0
    var carbs_g: Double = 0
    var fat_g: Double = 0
    enum CodingKeys: String, CodingKey { case name, brand, portion, calories, protein_g, carbs_g, fat_g }
    var asItem: MealEstimate.Item {
        let (q, u) = MealEstimate.Item.parsePortion(portion)
        return .init(name: name, portion: portion.isEmpty ? nil : portion,
                     calories: calories, protein_g: protein_g, carbs_g: carbs_g, fat_g: fat_g, quantity: q, unit: u)
    }
    var asMeal: MealEstimate {
        var m = MealEstimate(name: name, calories: calories, protein_g: protein_g, carbs_g: carbs_g, fat_g: fat_g, confidence: "catalog")
        m.items = [asItem]
        return m
    }
}

// A daily readiness check-in.
struct CheckIn: Codable, Identifiable {
    var id: String?
    var log_date: String?
    var mood: Int = 3
    var confidence: Int = 3
    var readiness: Int = 3
    var training_day: Bool = false
    enum CodingKeys: String, CodingKey { case id, log_date, mood, confidence, readiness, training_day }
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
    static var today: String { string(AppClock.now) }
}

// Training streak with a one-day grace — James Clear's "never miss twice." A single
// missed day is forgiven; two missed days in a row breaks it. Today-in-progress is
// never counted as a miss.
enum Streak {
    static func count(from dateStrings: [String]) -> Int {
        let cal = Calendar.current
        let days = Set(dateStrings.compactMap { LogDate.fmt.date(from: $0) }.map { cal.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }
        let today = cal.startOfDay(for: AppClock.now)
        var cursor = days.contains(today) ? today : cal.date(byAdding: .day, value: -1, to: today)!
        var count = 0, misses = 0
        while true {
            if days.contains(cursor) { count += 1; misses = 0 }
            else { misses += 1; if misses >= 2 { break } }
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    // True when yesterday was missed but the streak is still alive — today is the
    // grace day to keep it going.
    static func graceActive(from dateStrings: [String]) -> Bool {
        let cal = Calendar.current
        let days = Set(dateStrings.compactMap { LogDate.fmt.date(from: $0) }.map { cal.startOfDay(for: $0) })
        let today = cal.startOfDay(for: AppClock.now)
        guard !days.contains(today),
              let y = cal.date(byAdding: .day, value: -1, to: today), !days.contains(y) else { return false }
        return count(from: dateStrings) > 0
    }
}
