import Foundation

// Central "now" for all day-based logic (streak, grace, deload, "today" logging).
// In DEBUG a day offset can fast-forward time without touching the device clock,
// so multi-day behavior can be verified in one sitting. In release it is just Date().
enum AppClock {
    static let offsetKey = "debugDayOffset"

    #if DEBUG
    static var dayOffset: Int {
        get { UserDefaults.standard.integer(forKey: offsetKey) }
        set { UserDefaults.standard.set(newValue, forKey: offsetKey) }
    }
    static var now: Date {
        Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
    }
    // Seed the offset once at launch from STETIC_DAY_OFFSET=N (Xcode scheme / simctl).
    static func seedFromEnv() {
        if let v = ProcessInfo.processInfo.environment["STETIC_DAY_OFFSET"], let n = Int(v) {
            dayOffset = n
        }
    }
    #else
    static var now: Date { Date() }
    static func seedFromEnv() {}
    #endif
}
