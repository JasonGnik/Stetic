import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("remindersOn") private var remindersOn = true
    @AppStorage("steticDays") private var steticDays = 4
    @AppStorage("healthConnected") private var healthConnected = false
    @State private var showRestoreNote = false

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
                    group("ABOUT") {
                        linkRow("Privacy Policy", "https://stetic.app/privacy")
                        linkRow("Terms of Use", "https://stetic.app/terms")
                        HStack { Text("Version").foregroundStyle(Theme.txt); Spacer(); Text(appVersion).foregroundStyle(Theme.mut) }
                            .font(.system(size: 14)).rowStyle()
                    }
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
        }
        .preferredColorScheme(.dark)
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
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
