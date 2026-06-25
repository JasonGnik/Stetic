import SwiftUI

struct ContentView: View {
    private let env = ProcessInfo.processInfo.environment
    @State private var stage: Stage
    @State private var userName = ""

    enum Stage { case intro, onboarding, main, home }

    init() {
        let e = ProcessInfo.processInfo.environment
        let start: Stage = e["STETIC_HOME"] == "1" ? .home
            : e["STETIC_SKIP_ONBOARDING"] == "1" ? .main
            : (e["STETIC_ONB_STEP"] != nil ? .onboarding : .intro)
        _stage = State(initialValue: start)
    }

    var body: some View {
        if env["STETIC_SHOWPLAN"] == "1" {
            PlanView()
        } else if env["STETIC_SHARECARD"] == "1" {
            ZStack { Theme.bg.ignoresSafeArea(); ShareCardView(card: .sample, name: "Jason") }
        } else if env["STETIC_SESSION"] == "1" {
            SessionLogView(day: .init(day: "Pull Day", focus: "Back, rear delts & biceps", exercises: [
                .init(name: "Weighted Pull-up", sets: 2, reps: "5-9, 10-12", target: "lats", note: nil),
                .init(name: "Chest-Supported Row", sets: 2, reps: "8-10", target: "upper back", note: nil),
                .init(name: "Incline Dumbbell Curl", sets: 3, reps: "6-9, 10-12, 15-20", target: "biceps", note: nil),
            ]), onDone: {})
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
                RevealFunnelView(name: userName, onFinish: { withAnimation { stage = .home } })
            case .home:
                MainTabView(name: userName)
            }
        }
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
