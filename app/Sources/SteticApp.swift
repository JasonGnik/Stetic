import SwiftUI

@main
struct SteticApp: App {
    init() { PurchaseManager.shared.configure() }   // no-op until the RC key is set
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
