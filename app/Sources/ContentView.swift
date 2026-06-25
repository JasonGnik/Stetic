import SwiftUI

struct ContentView: View {
    private let env = ProcessInfo.processInfo.environment
    @State private var stage: Stage
    @State private var userName = ""
    @AppStorage("steticOnboarded") private var onboarded = false

    enum Stage { case loading, signIn, intro, onboarding, main, home }

    init() {
        let e = ProcessInfo.processInfo.environment
        // Dev flags use the dev account and skip the sign-in gate.
        let devStart: Stage? = e["STETIC_HOME"] == "1" ? .home
            : e["STETIC_SKIP_ONBOARDING"] == "1" ? .main
            : (e["STETIC_ONB_STEP"] != nil ? .onboarding : nil)
        _stage = State(initialValue: devStart ?? .loading)
    }

    private func checkSession() async {
        if await ScanAPI.shared.restoreSession() {
            if let uid = await ScanAPI.shared.currentUserID() { await PurchaseManager.shared.identify(uid) }
            stage = onboarded ? .home : .intro
        } else {
            stage = .signIn
        }
    }

    var body: some View {
        if env["STETIC_SHOWPLAN"] == "1" {
            PlanView()
        } else if env["STETIC_SCORECARD"] == "1" {
            ScoreCardExport()
        } else if env["STETIC_SETTINGS"] == "1" {
            SettingsView()
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
            case .loading:
                ZStack { Theme.bg.ignoresSafeArea() }.task { await checkSession() }
            case .signIn:
                SignInView { withAnimation { stage = .intro } }
            case .intro:
                IntroView { withAnimation { stage = .onboarding } }
            case .onboarding:
                OnboardingView { name in
                    userName = name
                    withAnimation { stage = .main }
                }
            case .main:
                RevealFunnelView(name: userName, onFinish: { onboarded = true; withAnimation { stage = .home } })
            case .home:
                MainTabView(name: userName)
            }
        }
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}

// DEV: renders full-length score-card PNGs (no scroll clipping) to the app's
// Documents dir, and shows the platinum one on screen for a device screenshot.
struct ScoreCardExport: View {
    var body: some View {
        ZStack { Theme.bg.ignoresSafeArea(); ScoreCardView(card: .sample) }
            .preferredColorScheme(.dark)
            .task { await exportAll() }
    }

    @MainActor private func exportAll() async {
        render(.sample, name: "scorecard-platinum.png")
        render(ScoreCardExport.eliteSample, name: "scorecard-elite.png")
    }

    @MainActor private func render(_ card: ScoreCard, name: String) {
        let content = ScoreCardBody(card: card)
            .frame(width: 402)
            .background(Theme.bg)
            .preferredColorScheme(.dark)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        guard let img = renderer.uiImage, let data = img.pngData() else { return }
        let url = URL.documentsDirectory.appending(path: name)
        try? data.write(to: url)
    }

    static let eliteSample = ScoreCard(
        aesthetic_score: 8.4, rank_tier: "elite", body_fat: 9, symmetry: 9.1, potential: 9.4,
        muscles: [
            .init(group: "abs", score: 9.2, visible: true, note: "Deep, defined"),
            .init(group: "shoulders", score: 8.9, visible: true, note: "Capped delts"),
            .init(group: "chest", score: 8.6, visible: true, note: "Full, square"),
            .init(group: "arms", score: 8.3, visible: true, note: "Strong peak"),
            .init(group: "legs", score: 8.0, visible: false, note: "Estimated"),
            .init(group: "back", score: 7.4, visible: false, note: "Needs width"),
        ],
        verdict: "An elite, stage-ready frame. Your back width is the one thing between you and Greek God — prioritize lats and you complete the V-taper.")
}
