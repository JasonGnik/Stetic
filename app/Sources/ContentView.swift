import SwiftUI

struct ContentView: View {
    var body: some View {
        // DEV: STETIC_SHOWPLAN=1 opens the Plan directly (uses the latest scan).
        if ProcessInfo.processInfo.environment["STETIC_SHOWPLAN"] == "1" {
            PlanView()
        } else {
            ScanFlowView()
        }
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
