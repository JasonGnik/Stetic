import SwiftUI

// Shown once, right after they enter the app with their plan: ask when they train so we can
// schedule training reminders (plus a daily morning check-in nudge).
struct WorkoutTimeSheet: View {
    let daysPerWeek: Int
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var time = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "bell.badge.fill").font(.system(size: 46)).foregroundStyle(Theme.acc)
                Text("When do you usually train?")
                    .font(.system(size: 25, weight: .heavy)).multilineTextAlignment(.center).foregroundStyle(Theme.txt)
                Text("We'll remind you on your training days — and nudge you each morning to check in.")
                    .font(.system(size: 14)).multilineTextAlignment(.center).lineSpacing(3)
                    .foregroundStyle(Theme.mut).padding(.horizontal, 34)
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().colorScheme(.dark)
                Spacer()
                Button { schedule(); finish() } label: {
                    Text("Set my reminders").font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(15)
                        .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
                        .foregroundStyle(Color(hex: 0x0E0E10))
                }
                .padding(.horizontal, 22)
                Button { finish() } label: {
                    Text("Not now").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.mut)
                }
                .padding(.bottom, 16)
            }
        }
    }

    private func schedule() {
        let hour = Calendar.current.component(.hour, from: time)
        NotificationManager.enableTrainingReminders(daysPerWeek: daysPerWeek, hour: hour)
        NotificationManager.enableCheckInReminder(hour: 9)
        UserDefaults.standard.set(hour, forKey: "workoutHour")
    }
    private func finish() { dismiss(); onDone() }
}
