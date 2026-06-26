import SwiftUI

// Per-meal "time to eat" reminders. Each meal can be toggled on with a time of day;
// saving (re)schedules the daily notifications.
struct MealRemindersView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("mealRemind.breakfast") private var breakfast = -1
    @AppStorage("mealRemind.lunch") private var lunch = -1
    @AppStorage("mealRemind.dinner") private var dinner = -1
    @AppStorage("mealRemind.snacks") private var snacks = -1

    private let defaults: [MealType: Int] = [.breakfast: 8, .lunch: 12, .dinner: 19, .snacks: 15]

    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(Theme.line).frame(width: 38, height: 5).padding(.top, 10)
            Text("Meal reminders").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
            Text("Get a nudge when it's time to eat.").font(.system(size: 12)).foregroundStyle(Theme.mut)

            row(.breakfast, $breakfast)
            row(.lunch, $lunch)
            row(.dinner, $dinner)
            row(.snacks, $snacks)

            Button { save() } label: {
                Text("Save").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.acc)).foregroundStyle(Color(hex: 0x0E0E10))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.height(430)])
    }

    private func row(_ type: MealType, _ hour: Binding<Int>) -> some View {
        let on = Binding(get: { hour.wrappedValue >= 0 },
                         set: { hour.wrappedValue = $0 ? (defaults[type] ?? 12) : -1 })
        return HStack(spacing: 12) {
            Image(systemName: type.icon).font(.system(size: 14)).foregroundStyle(Theme.acc).frame(width: 22)
            Text(type.label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
            Spacer()
            if hour.wrappedValue >= 0 {
                DatePicker("", selection: Binding(
                    get: { Calendar.current.date(bySettingHour: hour.wrappedValue, minute: 0, second: 0, of: Date()) ?? Date() },
                    set: { hour.wrappedValue = Calendar.current.component(.hour, from: $0) }),
                    displayedComponents: .hourAndMinute)
                    .labelsHidden().colorScheme(.dark)
            }
            Toggle("", isOn: on).labelsHidden().tint(Theme.acc)
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1)))
    }

    private func save() {
        var hours: [MealType: Int] = [:]
        for (t, h) in [(MealType.breakfast, breakfast), (.lunch, lunch), (.dinner, dinner), (.snacks, snacks)] where h >= 0 {
            hours[t] = h
        }
        NotificationManager.setMealReminders(hours)
        dismiss()
    }
}
