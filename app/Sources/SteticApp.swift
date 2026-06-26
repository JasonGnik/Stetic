import SwiftUI

@main
struct SteticApp: App {
    init() {
        AppClock.seedFromEnv()                       // DEBUG day-offset from STETIC_DAY_OFFSET
        PurchaseManager.shared.configure()           // no-op until the RC key is set
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
