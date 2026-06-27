import SwiftUI

struct ContentView: View {
    private let env = ProcessInfo.processInfo.environment
    @State private var stage: Stage
    @State private var userName = ""
    @State private var pendingProfile: ScanAPI.ProfileInput?   // held until sign-in (right before paywall)
    @State private var pendingIdentity = IdentityInputs()      // onboarding answers for the funnel's identity beat
    @AppStorage("steticOnboarded") private var onboarded = false

    enum Stage { case loading, welcome, intro, onboarding, main, home }

    init() {
        let e = ProcessInfo.processInfo.environment
        // Dev flags use the dev account and skip the sign-in gate.
        let devStart: Stage? = e["STETIC_HOME"] == "1" ? .home
            : e["STETIC_SKIP_ONBOARDING"] == "1" ? .main
            : (e["STETIC_ONB_STEP"] != nil ? .onboarding : nil)
        _stage = State(initialValue: devStart ?? .loading)
    }

    private func checkSession() async {
        // No sign-in gate up front — new users go straight into the funnel and only
        // create an account right before the paywall. Returning, onboarded users skip to home.
        if await ScanAPI.shared.restoreSession() {
            if let uid = await ScanAPI.shared.currentUserID() { await PurchaseManager.shared.identify(uid) }
            stage = onboarded ? .home : .welcome
        } else {
            stage = .welcome
        }
    }

    #if DEBUG
    // Dev fast-path: sign in the dev account, mark onboarded (persists), jump to the app.
    // After pressing once, future launches restore the session and land on home directly.
    private func devSkip() async {
        try? await ScanAPI.shared.ensureSession()
        if let uid = await ScanAPI.shared.currentUserID() { await PurchaseManager.shared.identify(uid) }
        onboarded = true
        withAnimation { stage = .home }
    }
    #endif

    var body: some View {
        if env["STETIC_SHOWPLAN"] == "1" {
            PlanView()
        } else if env["STETIC_FUNNEL_PHASE"] != nil {
            RevealFunnelView(name: "Jason", profile: nil, onFinish: {})
        } else if env["STETIC_SCORECARD"] == "1" {
            ScoreCardExport()
        } else if env["STETIC_SETTINGS"] == "1" {
            SettingsView()
        } else if env["STETIC_SHARECARD"] == "1" {
            ZStack { Theme.bg.ignoresSafeArea(); ShareCardView(card: .sample, name: "Jason") }
        } else if env["STETIC_FOODEDIT"] == "1" {
            ZStack { Theme.bg.ignoresSafeArea()
                FoodItemEditor(item: .init(name: "Chicken breast", portion: "150 g", calories: 248, protein_g: 47, carbs_g: 0, fat_g: 6, quantity: 150, unit: "g"), onSave: { _ in }, onCancel: {}) }
        } else if env["STETIC_MEALUPLOAD"] == "1" {
            MealUploadProbe()
        } else if env["STETIC_MEALDETAIL"] == "1" {
            MealDetailView(log: .init(id: "x", log_date: LogDate.today, name: "Pasta with Tuna Tartare & Pizza",
                calories: 1370, protein_g: 70, carbs_g: 160, fat_g: 51, meal_type: "dinner",
                items: [.init(name: "Green Pasta with Tuna Tartare", portion: "~400g", calories: 570, protein_g: 40, carbs_g: 60, fat_g: 22),
                        .init(name: "Margherita Pizza", portion: "~350g (whole)", calories: 800, protein_g: 30, carbs_g: 100, fat_g: 29)]),
                onChange: {})
        } else if env["STETIC_CHECKIN"] == "1" {
            CheckInView(trainingDay: true, history: [], workoutDates: [], onStartSession: {}, onDone: {})
        } else if env["STETIC_CRAVING"] == "1" {
            CravingView(target: .init(calories: 2600, protein_g: 190, carbs_g: 300, fat_g: 70, rationale: ""),
                        consumed: (1200, 90, 140, 30)) { _ in }
        } else if env["STETIC_FOODCAM"] == "1" {
            FoodCameraView(onCapture: { _, _ in }, onBarcode: { _ in })   // DEV: preview the capture overlay
        } else if env["STETIC_MEALSCAN"] == "3" {
            MealCoverProbe()   // DEV: present MealScanView in a fullScreenCover like the Food tab
        } else if env["STETIC_MEALSCAN"] == "2" {
            // DEV: exercise the live scanning animation (no preset → runs the loader).
            MealScanView(image: UIImage(named: "sample") ?? UIImage(), dataB64: "", onLogged: {})
        } else if env["STETIC_MEALSCAN"] == "1" {
            MealScanView(image: UIImage(named: "sample") ?? UIImage(),
                         dataB64: "", onLogged: {},
                         preset: MealEstimate(
                            name: "Caesar salad with chicken",
                            items: [
                                .init(name: "Grilled chicken", portion: "~150g", calories: 250, protein_g: 46, carbs_g: 0, fat_g: 6),
                                .init(name: "Romaine lettuce", portion: "2 cups", calories: 16, protein_g: 1, carbs_g: 3, fat_g: 0),
                                .init(name: "Parmesan", portion: "2 tbsp", calories: 43, protein_g: 4, carbs_g: 1, fat_g: 3),
                                .init(name: "Croutons", portion: "1/4 cup", calories: 31, protein_g: 1, carbs_g: 5, fat_g: 1),
                                .init(name: "Caesar dressing", portion: "1 tbsp", calories: 80, protein_g: 1, carbs_g: 1, fat_g: 9),
                            ],
                            calories: 420, protein_g: 53, carbs_g: 10, fat_g: 19, confidence: "high"))
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
            case .welcome:
                ZStack(alignment: .top) {
                    WelcomeView { withAnimation { stage = .intro } }
                    #if DEBUG
                    Button { Task { await devSkip() } } label: {
                        Text("Dev: skip to app →").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.acc)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Theme.card))
                    }
                    .padding(.top, 8)
                    #endif
                }
            case .intro:
                IntroView { withAnimation { stage = .onboarding } }
            case .onboarding:
                OnboardingView { data in
                    userName = data.name
                    pendingProfile = data.payload   // saved after sign-in, inside the funnel
                    pendingIdentity = IdentityInputs(years: Int(data.timeWantedYears),
                                                     obstacles: Array(data.obstacles),
                                                     resultsBehind: data.resultsFeeling == "behind")
                    withAnimation { stage = .main }
                }
            case .main:
                RevealFunnelView(name: userName, profile: pendingProfile, identity: pendingIdentity,
                                 onFinish: { onboarded = true; withAnimation { stage = .home } })
            case .home:
                MainTabView(name: userName)
            }
        }
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}

// DEV: reproduces the upload path — camera cover dismisses, scan cover presents via
// the onChange dance (the exact two-fullScreenCover sequence the real flow uses).
struct MealUploadProbe: View {
    enum Phase { case camera, scan }
    @State private var phase: Phase = .camera
    @State private var img: UIImage?
    @State private var b64 = ""
    private var sample: (UIImage, String) {
        let url = Bundle.main.url(forResource: "sample", withExtension: "jpg")
        let data = (url.flatMap { try? Data(contentsOf: $0) }) ?? Data()
        return (UIImage(data: data) ?? UIImage(), data.base64EncodedString())
    }
    var body: some View {   // mirrors FoodCaptureFlow's internal camera→scan swap
        ZStack {
            switch phase {
            case .camera:
                ZStack { Color.black.ignoresSafeArea(); ProgressView().tint(.white) }
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        let s = sample; img = s.0; b64 = s.1; phase = .scan } }
            case .scan:
                MealScanView(image: img ?? UIImage(), dataB64: b64, onLogged: {}).id(b64)
            }
        }
    }
}

// DEV: reproduces the Food-tab presentation (MealScanView in a fullScreenCover).
struct MealCoverProbe: View {
    @State private var show = false
    private var sample: (UIImage, String) {
        let url = Bundle.main.url(forResource: "sample", withExtension: "jpg")
        let data = (url.flatMap { try? Data(contentsOf: $0) }) ?? Data()
        let img = UIImage(data: data) ?? UIImage()
        return (img, data.base64EncodedString())
    }
    var body: some View {
        ZStack { Theme.bg.ignoresSafeArea() }
            .onAppear { show = true }
            .fullScreenCover(isPresented: $show) {
                MealScanView(image: sample.0, dataB64: sample.1, onLogged: {})
            }
    }
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
