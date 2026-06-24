import SwiftUI

struct ContentView: View {
    private let env = ProcessInfo.processInfo.environment
    // Dev: skip straight past onboarding when testing scan/plan.
    @State private var inMain = ProcessInfo.processInfo.environment["STETIC_SKIP_ONBOARDING"] == "1"

    var body: some View {
        if env["STETIC_SHOWPLAN"] == "1" {
            PlanView()
        } else if inMain {
            ScanFlowView()
        } else {
            OnboardingView { withAnimation { inMain = true } }
        }
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
