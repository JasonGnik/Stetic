import UserNotifications

// Weekly training reminders, spread across the user's chosen training days.
enum NotificationManager {
    static func enableTrainingReminders(daysPerWeek: Int, hour: Int = 17) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            center.removePendingNotificationRequests(withIdentifiers: weekdayIds)
            for wd in spread(daysPerWeek) {
                var dc = DateComponents(); dc.weekday = wd; dc.hour = hour
                let content = UNMutableNotificationContent()
                content.title = "Stetic"
                content.body = "Time to train — keep your streak alive."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                center.add(UNNotificationRequest(identifier: "stetic.train.\(wd)", content: content, trigger: trigger))
            }
        }
    }

    // Schedule reminders on specific weekdays at a chosen hour (from the Today schedule).
    static func setTrainingReminders(weekdays: Set<Int>, hour: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            center.removePendingNotificationRequests(withIdentifiers: weekdayIds)
            for wd in weekdays where (1...7).contains(wd) {
                var dc = DateComponents(); dc.weekday = wd; dc.hour = hour
                let content = UNMutableNotificationContent()
                content.title = "Stetic"
                content.body = "Time to train — keep your streak alive."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                center.add(UNNotificationRequest(identifier: "stetic.train.\(wd)", content: content, trigger: trigger))
            }
        }
    }

    static func disableTrainingReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: weekdayIds)
    }

    private static var weekdayIds: [String] { (1...7).map { "stetic.train.\($0)" } }

    // Daily meal reminders. Pass an hour per meal type (-1 / missing = off).
    static func setMealReminders(_ hours: [MealType: Int]) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            center.removePendingNotificationRequests(withIdentifiers: mealIds)
            for (type, hour) in hours where (0...23).contains(hour) {
                var dc = DateComponents(); dc.hour = hour
                let content = UNMutableNotificationContent()
                content.title = "Stetic"
                content.body = mealBody(type)
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                center.add(UNNotificationRequest(identifier: "stetic.meal.\(type.rawValue)", content: content, trigger: trigger))
            }
        }
    }

    private static var mealIds: [String] { MealType.allCases.map { "stetic.meal.\($0.rawValue)" } }
    private static func mealBody(_ t: MealType) -> String {
        switch t {
        case .breakfast: return "Breakfast time — start the day with protein."
        case .lunch:     return "Lunch time — fuel up and stay on target."
        case .dinner:    return "Dinner time — log it to close out your day."
        case .snacks:    return "Snack time — keep your protein topped up."
        }
    }

    // weekday: 1=Sun, 2=Mon … 7=Sat. Spread N sessions sensibly across the week.
    private static func spread(_ n: Int) -> [Int] {
        switch max(1, min(7, n)) {
        case 1: return [2]
        case 2: return [2, 5]
        case 3: return [2, 4, 6]
        case 4: return [2, 3, 5, 6]
        case 5: return [2, 3, 4, 5, 6]
        case 6: return [2, 3, 4, 5, 6, 7]
        default: return [1, 2, 3, 4, 5, 6, 7]
        }
    }
}
