import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("remindersOn") private var remindersOn = true
    @AppStorage("steticDays") private var steticDays = 4
    @AppStorage("healthConnected") private var healthConnected = false
    @AppStorage(AppClock.offsetKey) private var debugDayOffset = 0
    @State private var showRestoreNote = false
    @State private var showLogOut = false
    @State private var showDelete = false
    @State private var deleting = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    group("TRAINING") {
                        toggleRow("Workout reminders", "bell.fill", isOn: $remindersOn)
                            .onChange(of: remindersOn) { _, on in
                                if on { NotificationManager.enableTrainingReminders(daysPerWeek: steticDays) }
                                else { NotificationManager.disableTrainingReminders() }
                            }
                    }
                    group("APPLE HEALTH") {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill").foregroundStyle(Color(hex: 0xFF6B6B))
                            Text(healthConnected ? "Connected" : "Not connected").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                            Spacer()
                            if !healthConnected {
                                Button("Connect") {
                                    Task { await HealthKitManager.shared.requestAuth(); healthConnected = true }
                                }.font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.acc)
                            }
                        }
                        .rowStyle()
                    }
                    group("SUBSCRIPTION") {
                        Button { showRestoreNote = true } label: { row("Restore purchases", "arrow.clockwise") }
                    }
                    group("ACCOUNT") {
                        Button { showLogOut = true } label: { row("Log out", "rectangle.portrait.and.arrow.right") }
                        Button { showDelete = true } label: {
                            HStack(spacing: 12) {
                                if deleting { ProgressView().tint(Color(hex: 0xFF5A4D)).frame(width: 20) }
                                else { Image(systemName: "trash.fill").foregroundStyle(Color(hex: 0xFF5A4D)).frame(width: 20) }
                                Text("Delete account").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: 0xFF5A4D))
                                Spacer()
                            }.rowStyle()
                        }.disabled(deleting)
                    }
                    group("ABOUT") {
                        linkRow("Privacy Policy", "https://jasongnik.github.io/stetic-legal/privacy.html")
                        linkRow("Terms of Use", "https://jasongnik.github.io/stetic-legal/terms.html")
                        HStack { Text("Version").foregroundStyle(Theme.txt); Spacer(); Text(appVersion).foregroundStyle(Theme.mut) }
                            .font(.system(size: 14)).rowStyle()
                    }
                    #if DEBUG
                    group("DEBUG — TIME TRAVEL") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.2.circlepath").foregroundStyle(Theme.acc).frame(width: 20)
                                Text("Day offset").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                                Spacer()
                                Text("\(debugDayOffset >= 0 ? "+" : "")\(debugDayOffset)d")
                                    .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.acc)
                                Stepper("", value: $debugDayOffset, in: -7...180).labelsHidden().tint(Theme.acc)
                            }
                            Text("Simulating \(simulatedDateString). Streak, grace & deload read this — log a workout to record it on that day.")
                                .font(.system(size: 11)).foregroundStyle(Theme.mut).lineSpacing(2)
                            if debugDayOffset != 0 {
                                Button("Reset to today") { debugDayOffset = 0 }
                                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.acc)
                            }
                        }.rowStyle()
                    }
                    #endif
                    Text("Stetic gives AI estimates to help you train — it is not medical, nutritional, or fitness advice. Talk to a qualified professional before changing your training or diet.")
                        .font(.system(size: 11)).foregroundStyle(Theme.mut).lineSpacing(3)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.foregroundStyle(Theme.acc)
            } }
            .alert("Restore purchases", isPresented: $showRestoreNote) {
                Button("OK", role: .cancel) {}
            } message: { Text("Nothing to restore yet — purchases will appear here once you subscribe.") }
            .alert("Log out?", isPresented: $showLogOut) {
                Button("Cancel", role: .cancel) {}
                Button("Log out", role: .destructive) {
                    ScanAPI.shared.signOut()
                    dismiss()
                    NotificationCenter.default.post(name: .steticLoggedOut, object: nil)
                }
            } message: { Text("You can log back in any time with the same account.") }
            .alert("Delete account?", isPresented: $showDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { deleteAccount() }
            } message: {
                Text("This permanently deletes your account, scans, plans and history. This can't be undone.")
            }
            .alert("Couldn't delete account", isPresented: .constant(deleteError != nil)) {
                Button("OK") { deleteError = nil }
            } message: { Text(deleteError ?? "") }
        }
        .preferredColorScheme(.dark)
    }

    private func deleteAccount() {
        deleting = true
        Task {
            do {
                try await ScanAPI.shared.deleteAccount()
                await MainActor.run {
                    deleting = false
                    dismiss()
                    NotificationCenter.default.post(name: .steticLoggedOut, object: nil)
                }
            } catch {
                await MainActor.run { deleting = false; deleteError = "Please try again, or contact support." }
            }
        }
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
    }

    private var simulatedDateString: String {
        let d = Calendar.current.date(byAdding: .day, value: debugDayOffset, to: Date()) ?? Date()
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: d)
    }

    @ViewBuilder private func group<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
            c()
        }
    }
    private func row(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.acc).frame(width: 20)
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
        }.rowStyle()
    }
    private func toggleRow(_ title: String, _ icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.acc).frame(width: 20)
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Theme.acc)
        }.rowStyle()
    }
    private func linkRow(_ title: String, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack { Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut) }
                .rowStyle()
        }
    }
}

private extension View {
    func rowStyle() -> some View {
        self.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
    }
}
