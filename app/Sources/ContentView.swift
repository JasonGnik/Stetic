import SwiftUI

struct ContentView: View {
    private let env = ProcessInfo.processInfo.environment
    @State private var stage: Stage
    @State private var userName = ""

    enum Stage { case intro, onboarding, main }

    init() {
        let e = ProcessInfo.processInfo.environment
        let start: Stage = e["STETIC_SKIP_ONBOARDING"] == "1" ? .main
            : (e["STETIC_ONB_STEP"] != nil ? .onboarding : .intro)
        _stage = State(initialValue: start)
    }

    var body: some View {
        if env["STETIC_SHOWPLAN"] == "1" {
            PlanView()
        } else {
            switch stage {
            case .intro:
                IntroView { withAnimation { stage = .onboarding } }
            case .onboarding:
                OnboardingView { name in
                    userName = name
                    withAnimation { stage = .main }
                }
            case .main:
                RevealFunnelView(name: userName)
            }
        }
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
