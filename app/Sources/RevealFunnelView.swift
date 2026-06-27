import SwiftUI
import PhotosUI
import RevenueCat

// The reveal funnel: capture the photo, build investment + FOMO with NO AI spend,
// gate the real Gemini scan behind a (stubbed) paywall, then reveal.
struct RevealFunnelView: View {
    var name: String = ""
    var profile: ScanAPI.ProfileInput? = nil   // onboarding answers; saved after sign-in
    var identity: IdentityInputs = .init()      // for the identity-transformation beat (post-scan)
    var rescan: Bool = false        // re-scan (already entitled): skip FOMO/paywall, go straight to scoring
    var onFinish: (() -> Void)? = nil

    // New flow: capture → bluff(fake scan) → identity → signin → paywall → real scan → result.
    enum Phase { case capture, focusPick, fomo, bluff, tease, identity, signin, paywall, trialReminder, scanning, result, error }
    @State private var phase: Phase = .capture
    @State private var focusSel: Set<String> = []   // no-photo path: areas to prioritize in the estimate
    @State private var items: [PhotosPickerItem?] = [nil, nil, nil]
    @State private var images: [UIImage?] = [nil, nil, nil]
    @State private var datas: [Data?] = [nil, nil, nil]
    @State private var includeLegs = false
    private let slotLabels = ["Front", "Side", "Back"]
    @State private var card: ScoreCard?
    @State private var errorMsg = ""
    @State private var showPlan = false
    @State private var didDevInit = false
    @State private var capturePage = 0           // front/side/back carousel page
    @State private var showCamera = false
    @State private var selectedPlan = "annual"   // annual | weekly

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            switch phase {
            case .capture:       capture
            case .focusPick:     focusPickView
            case .fomo:          fomo
            case .bluff:         bluff
            case .tease:         tease
            case .identity:      identityView
            case .signin:        signinView
            case .paywall:       paywall
            case .trialReminder: trialReminderView
            case .scanning:      scanningView
            case .result:        resultView
            case .error:         errorView
            }
        }
        .task { devInit() }
    }

    private var hasAnyPhoto: Bool { datas.contains { $0 != nil } }

    // MARK: capture — a sleek front/side/back carousel. Front is required, others sharpen it.
    private var capture: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 6)
            VStack(spacing: 6) {
                Text("STETIC").font(.system(size: 30, weight: .heavy)).tracking(3).foregroundStyle(Theme.acc)
                Text("Scan your physique").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.mut)
            }
            TabView(selection: $capturePage) {
                ForEach(0..<3, id: \.self) { i in carouselCard(i).tag(i) }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 400)

            // angle dots — lime once that angle has a photo, wide pill for the current page
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(images[i] != nil ? Theme.acc : (i == capturePage ? Theme.mut : Theme.line))
                        .frame(width: i == capturePage ? 22 : 7, height: 7)
                        .onTapGesture { withAnimation { capturePage = i } }
                }
            }

            Button { showCamera = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "camera.fill").font(.system(size: 14, weight: .semibold))
                    Text("Take \(slotLabels[capturePage].lowercased()) photo").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Theme.acc)
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.acc.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.acc.opacity(0.35), lineWidth: 1)))
            }
            .padding(.horizontal, 22)
            Text("or tap the card to choose from your library").font(.system(size: 11)).foregroundStyle(Theme.mut)

            Toggle(isOn: $includeLegs) {
                Text("Include legs (full-body score)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
            }
            .tint(Theme.acc).padding(.horizontal, 26)

            Text(includeLegs ? "Stand back so your legs are in frame."
                             : "Front is required — swipe for side & back to sharpen your score.")
                .font(.system(size: 12)).foregroundStyle(Theme.mut).multilineTextAlignment(.center).padding(.horizontal, 30)

            Button { withAnimation { rescan ? startRealScan() : (phase = .bluff) } } label: {
                Text(rescan ? "Score my physique" : "Continue").font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(hasAnyPhoto ? Theme.acc : Theme.line))
                    .foregroundStyle(hasAnyPhoto ? Color(hex: 0x0E0E10) : Theme.mut)
            }
            .disabled(!hasAnyPhoto)
            .padding(.horizontal, 26)
            if !rescan {
                Button { withAnimation { phase = .focusPick } } label: {
                    Text("Skip — build my plan from my answers")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 6)
        }
        .onChange(of: items[0]) { _, v in Task { await load(0, v) } }
        .onChange(of: items[1]) { _, v in Task { await load(1, v) } }
        .onChange(of: items[2]) { _, v in Task { await load(2, v) } }
        .sheet(isPresented: $showCamera) {
            CameraPicker { img in
                let slot = capturePage
                images[slot] = img
                datas[slot] = img.jpegData(compressionQuality: 0.85)
                showCamera = false
            }
            .ignoresSafeArea()
        }
    }

    // One large angle card in the capture carousel.
    private func carouselCard(_ i: Int) -> some View {
        let filled = images[i] != nil
        return PhotosPicker(selection: $items[i], matching: .images) {
            ZStack(alignment: .topLeading) {
                Theme.card   // letterbox behind a fitted photo so nothing looks cropped
                if let img = images[i] {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 11) {
                        Image(systemName: i == 0 ? "person.crop.rectangle" : "plus.viewfinder")
                            .font(.system(size: 40, weight: .semibold)).foregroundStyle(i == 0 ? Theme.acc : Theme.mut)
                        Text("Add your \(slotLabels[i].lowercased()) photo")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.txt)
                        Text(i == 0 ? "Required" : "Optional")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.mut)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                HStack(spacing: 5) {
                    Text(slotLabels[i].uppercased()).font(.system(size: 11, weight: .bold)).tracking(1)
                    if filled { Image(systemName: "checkmark.circle.fill").font(.system(size: 11)) }
                }
                .foregroundStyle(filled ? Color(hex: 0x0E0E10) : Theme.txt)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Capsule().fill(filled ? Theme.acc : Color.black.opacity(0.55)))
                .padding(13)
            }
            .frame(maxWidth: .infinity).frame(height: 380)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(filled ? Theme.acc.opacity(0.5) : Theme.line, lineWidth: 1))
            .padding(.horizontal, 22)
        }
        .buttonStyle(.plain)
    }

    // MARK: focus pick — only on the no-photo path, to sharpen the estimate.
    private var focusPickView: some View {
        VStack(spacing: 0) {
            HStack {
                Button { withAnimation { phase = .capture } } label: {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                }
                Spacer()
            }
            .padding(.horizontal, 22).padding(.top, 8)
            VStack(alignment: .leading, spacing: 6) {
                Text("No photo? No problem.").font(.system(size: 25, weight: .heavy)).foregroundStyle(Theme.txt)
                Text("Which areas do you most want to bring up? We'll prioritize them in your plan.")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22).padding(.top, 14)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(OnbOptions.focus) { o in
                        let on = focusSel.contains(o.id)
                        Button {
                            if on { focusSel.remove(o.id) } else { focusSel.insert(o.id) }
                        } label: {
                            HStack {
                                Text(o.label).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.txt)
                                Spacer()
                                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20)).foregroundStyle(on ? Theme.acc : Theme.line)
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 14).fill(on ? Theme.acc.opacity(0.08) : Theme.card)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(on ? Theme.acc : Theme.line, lineWidth: on ? 1.5 : 1)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22).padding(.top, 18)
            }
            .scrollIndicators(.hidden)
            primaryButton("Continue") { withAnimation { phase = .bluff } }
        }
    }

    // Heuristic projection from their answers (no AI) — drives the personalized FOMO.
    private var projectedTiers: (plateau: String, potential: String) {
        let base = ["beginner": 3.4, "intermediate": 5.2, "advanced": 6.6][profile?.experience ?? ""] ?? 4.5
        let active = profile?.activity == "active" || profile?.activity == "very_active"
        let current = base + (active ? 0.3 : 0)
        let potential = min(9.5, current + 2.6)
        return (Tier.forScore(current).label, Tier.forScore(potential).label)
    }

    // MARK: FOMO — before → after payoff (illustrative, no AI yet)
    private var fomo: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 10) {
                Text("YOUR 12-WEEK PROJECTION").font(.system(size: 11, weight: .bold)).tracking(2).foregroundStyle(Theme.mut)
                Text(brandLimed(name.isEmpty ? "Here's where you\ncould be." : "\(name), here's where\nyou could be."))
                    .font(.system(size: 27, weight: .heavy)).multilineTextAlignment(.center).foregroundStyle(Theme.txt)
            }
            WithVsWithoutChart().frame(height: 184).padding(.horizontal, 30).padding(.top, 22)
            Text(brandLimed("With a plan built on your weak points, every week shows — leaner, fuller, more complete. Most people stall without one. Stetic closes that gap."))
                .font(.system(size: 14)).multilineTextAlignment(.center).lineSpacing(4)
                .foregroundStyle(Theme.mut).padding(.horizontal, 34).padding(.top, 20)
            Spacer()
            primaryButton("See my potential") { withAnimation { phase = .bluff } }
        }
    }

    private func tierPill(_ label: String, _ tier: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased()).font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
            Text(tier).font(.system(size: 18, weight: .heavy)).foregroundStyle(color)
        }
        .frame(minWidth: 104).padding(.vertical, 12).padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.4), lineWidth: 1)))
    }

    // MARK: bluff loader (NO AI)
    private var bluff: some View {
        ScanningLoader(
            title: "Analyzing your physique",
            messages: ["Mapping your frame", "Reading proportions & symmetry",
                       "Estimating body composition", "Finding your weak points", "Calibrating your score"],
            icons: ["figure.arms.open", "ruler", "drop.fill", "scope", "star.fill"]
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
                if phase == .bluff { withAnimation { phase = .identity } }   // → identity transformation (tease/lock deleted)
            }
        }
    }

    // MARK: identity transformation — the last emotional beat before sign-in + paywall
    private var identityView: some View {
        TransformationScreen(inputs: identity,
                             onContinue: { withAnimation { phase = .signin } },
                             onBack: { withAnimation { phase = .bluff } })
    }

    // MARK: tease — blurred result behind a lock (no longer in the flow; kept for dev preview)
    private var tease: some View {
        ZStack {
            ScoreCardView(card: .sample).blur(radius: 26).disabled(true).allowsHitTesting(false)
            LinearGradient(colors: [Theme.bg.opacity(0.65), Theme.bg.opacity(0.97)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "lock.fill").font(.system(size: 30)).foregroundStyle(Theme.acc)
                Text(name.isEmpty ? "Your analysis is ready" : "\(name), your analysis is ready")
                    .font(.system(size: 25, weight: .heavy)).multilineTextAlignment(.center).foregroundStyle(Theme.txt)
                    .padding(.horizontal, 30)
                Text("Here's what we found:").font(.system(size: 13)).foregroundStyle(Theme.mut)
                VStack(spacing: 10) {
                    findingRow("exclamationmark.triangle.fill", "3 lagging muscle groups", Theme.red)
                    findingRow("aspectratio.fill", "1 proportion breaking your frame", Theme.amber)
                    findingRow("rosette", "Your score, rank & full plan", Theme.acc)
                }
                .padding(.horizontal, 26)
                Spacer()
                primaryButton("Unlock my results") { withAnimation { phase = .signin } }
            }
        }
    }

    private func findingRow(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color).frame(width: 22)
            Text(text).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
            Spacer()
            Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Theme.mut)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.35), lineWidth: 1))
        )
    }

    // MARK: sign in — right before the paywall, after they've invested + seen the FOMO.
    private var signinView: some View {
        SignInView(
            title: name.isEmpty ? "Almost there." : "Almost there, \(name).",
            subtitle: "Create your account to unlock your score, rank & personalized plan."
        ) {
            // Persist the onboarding answers now that we have a session, then show the paywall.
            Task {
                if var p = profile {
                    if !focusSel.isEmpty { p.focus = Array(focusSel) }   // no-photo path focus areas
                    try? await ScanAPI.shared.saveProfile(p)
                    try? await ScanAPI.shared.logWeight(p.weightKg)        // seed Progress with the onboarding weight
                }
                await MainActor.run { withAnimation { phase = .paywall } }
            }
        }
    }

    // MARK: trial reminder — reassurance beat between the paywall CTA and the actual purchase.
    private var trialReminderView: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "bell.badge.fill").font(.system(size: 46)).foregroundStyle(Theme.acc)
            Text(brandLimed("We'll remind you\nbefore it ends."))
                .font(.system(size: 27, weight: .heavy)).multilineTextAlignment(.center).foregroundStyle(Theme.txt)
                .padding(.top, 18)
            Text("No payment now — cancel anytime in two taps.")
                .font(.system(size: 14)).foregroundStyle(Theme.mut).padding(.top, 6)
            VStack(alignment: .leading, spacing: 16) {
                trialStep("Today", "Everything unlocks — your scan, score & plan.", "lock.open.fill", highlight: true)
                trialStep("Day 2", "We send a reminder that your trial is ending.", "bell.fill", highlight: false)
                trialStep("Day 3", "Trial ends — you're only billed if you stay.", "checkmark.seal.fill", highlight: false)
            }
            .padding(.horizontal, 34).padding(.top, 30)
            Spacer()
            primaryButton("Start my free trial") { purchaseAndScan() }
            Button { withAnimation { phase = .paywall } } label: {
                Text("Maybe later").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut)
            }
            .padding(.bottom, 8)
        }
    }

    private func trialStep(_ day: String, _ text: String, _ icon: String, highlight: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(highlight ? Theme.acc : Theme.card).frame(width: 38, height: 38)
                    .overlay(Circle().stroke(highlight ? Theme.acc : Theme.line, lineWidth: 1))
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(highlight ? Color(hex: 0x0E0E10) : Theme.acc)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(day).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                Text(text).font(.system(size: 12.5)).foregroundStyle(Theme.mut).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    // MARK: paywall (RevenueCat; falls back to built-in prices + dev path when the key isn't set)
    @ObservedObject private var purchases = PurchaseManager.shared
    @State private var purchasing = false

    private var annualPkg: Package? { purchases.annual }
    private var weeklyPkg: Package? { purchases.weekly }
    private var selectedPackage: Package? { selectedPlan == "annual" ? annualPkg : weeklyPkg }

    private func perWeek(_ p: StoreProduct) -> String {
        let weekly = NSDecimalNumber(decimal: p.price).dividing(by: NSDecimalNumber(value: 52))
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = p.currencyCode
        return f.string(from: weekly) ?? p.localizedPriceString
    }

    private func purchaseAndScan() {
        // No RC key yet / simulator → just proceed (dev path).
        guard purchases.configured, let pkg = selectedPackage else { startRealScan(); return }
        purchasing = true
        Task {
            let ok = await purchases.purchase(pkg)
            purchasing = false
            if ok { startRealScan() }
        }
    }

    private let perks = [
        "Your physique score & rank",
        "A full breakdown of your weak points",
        "A workout plan to sculpt a complete physique",
        "A nutrition plan dialed to your goal",
        "Re-scan to track your ascension",
    ]

    private var paywall: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    VStack(spacing: 8) {
                        Text(name.isEmpty ? "Your plan is ready." : "Your plan is ready, \(name).")
                            .font(.system(size: 25, weight: .heavy)).multilineTextAlignment(.center).foregroundStyle(Theme.txt)
                        Text("Built for you.").font(.system(size: 14)).foregroundStyle(Theme.mut)
                    }
                    VStack(alignment: .leading, spacing: 11) {
                        ForEach(perks, id: \.self) { perk in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 17)).foregroundStyle(Theme.acc)
                                Text(perk).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.txt)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 30).padding(.top, 22)

                    VStack(spacing: 12) {
                        planRow("annual", "Annual",
                                annualPkg.map { perWeek($0.storeProduct) } ?? "$1.15", "/wk",
                                annualPkg.map { "\($0.storeProduct.localizedPriceString)/yr · 3-day free trial" } ?? "$59.99/yr · 3-day free trial",
                                best: true)
                        planRow("weekly", "Weekly",
                                weeklyPkg?.storeProduct.localizedPriceString ?? "$9.99", "/wk",
                                "Billed weekly", best: false)
                    }
                    .padding(.horizontal, 22).padding(.top, 24)

                    reviewsCarousel.padding(.top, 22)
                }
            }
            .scrollIndicators(.hidden)

            Button {
                purchaseAndScan()   // trial-reminder screen removed — buy directly
            } label: {
                HStack(spacing: 8) {
                    if purchasing { ProgressView().tint(Color(hex: 0x0E0E10)) }
                    Text(selectedPlan == "annual" ? "Start my 3-day free trial" : "Continue with weekly")
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity).padding(15)
                .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
                .foregroundStyle(Color(hex: 0x0E0E10))
            }
            .disabled(purchasing)
            .padding(.horizontal, 22).padding(.bottom, 14)

            Text(paywallTerms)
                .font(.system(size: 10.5)).multilineTextAlignment(.center).foregroundStyle(Theme.mut)
                .padding(.horizontal, 30).padding(.top, 2).padding(.bottom, 6)
            HStack(spacing: 14) {
                Button {
                    Task { if await purchases.restore() { startRealScan() } }
                } label: {
                    Text("Restore").font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
                Text("·").font(.system(size: 12)).foregroundStyle(Theme.line)
                Link("Terms", destination: URL(string: "https://jasongnik.github.io/stetic-legal/terms.html")!)
                    .font(.system(size: 12)).tint(Theme.mut)
                Text("·").font(.system(size: 12)).foregroundStyle(Theme.line)
                Link("Privacy", destination: URL(string: "https://jasongnik.github.io/stetic-legal/privacy.html")!)
                    .font(.system(size: 12)).tint(Theme.mut)
            }
            .padding(.bottom, 12)

            #if DEBUG
            // Dev only — skip the purchase and run the real scan with the dev account.
            Button { startRealScan() } label: {
                Text("Dev: skip paywall →").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.acc)
            }
            .padding(.bottom, 14)
            #endif
        }
        .task { await purchases.loadOffering() }
    }

    // Placeholder testimonials — swap for real App Store reviews before launch.
    private let reviews: [(String, String)] = [
        ("Climbed from Gold to Diamond in 8 weeks — and I'm in the gym less, not more.", "Dev R."),
        ("Leaner than I've ever been. First time I walk around actually confident in a t-shirt.", "Marcus T."),
        ("Smart programming, not bro science. More progress in 10 weeks than my last 2 years.", "Tyler J."),
        ("Dropped the fat, abs finally showing, and I know exactly what to do every session.", "Sam K."),
    ]

    private var reviewsCarousel: some View {
        TabView {
            ForEach(reviews.indices, id: \.self) { i in
                VStack(spacing: 9) {
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(Theme.acc)
                        }
                    }
                    Text("“\(reviews[i].0)”").font(.system(size: 13.5)).foregroundStyle(Color(hex: 0xD2D2D8))
                        .multilineTextAlignment(.center).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    Text("— \(reviews[i].1)").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 26).padding(.top, 4)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 132)
    }

    private var paywallTerms: String {
        selectedPlan == "annual"
            ? "No payment now. 3-day free trial, then $59.99/year. Auto-renews unless cancelled 24h before the trial ends. Cancel anytime."
            : "$9.99 per week, billed weekly. Cancel anytime in Settings."
    }

    private func planRow(_ id: String, _ title: String, _ price: String, _ unit: String, _ detail: String, best: Bool) -> some View {
        let selected = selectedPlan == id
        return Button { withAnimation(.easeOut(duration: 0.15)) { selectedPlan = id } } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20)).foregroundStyle(selected ? Theme.acc : Theme.line)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                        if best {
                            Text("BEST VALUE").font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Theme.acc)).foregroundStyle(Color(hex: 0x0E0E10))
                        }
                    }
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                    if best {
                        Text("Save 88% vs paying weekly").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.acc)
                    }
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(price).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.txt)
                    Text(unit).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(selected ? Theme.acc.opacity(0.08) : Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Theme.acc : Theme.line, lineWidth: selected ? 1.5 : 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: scanning (REAL Gemini) + result
    private var scanningView: some View {
        ScanningLoader(
            title: "Scoring your physique",
            messages: ["Sending to the model", "Scoring leanness & proportion",
                       "Ranking your muscle groups", "Computing your Stetic Score", "Finalizing"],
            icons: ["bolt.fill", "drop.fill", "list.number", "star.fill", "checkmark.seal.fill"]
        )
    }

    private var resultView: some View {
        Group {
            if let card {
                if rescan {
                    // Progress update: show the new score, no plan CTA, a Done button to return.
                    VStack(spacing: 0) {
                        ScoreCardView(card: card, showPlanCTA: false)
                        primaryButton("Done") { onFinish?() }
                    }
                } else {
                    ScoreCardView(card: card, onGetPlan: { showPlan = true })
                        .fullScreenCover(isPresented: $showPlan) {
                            PlanView(onStart: { showPlan = false; onFinish?() })
                        }
                }
            }
        }
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Text("Couldn't complete the scan").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
            Text(errorMsg).font(.system(size: 12)).foregroundStyle(Theme.mut).multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Try again") { reset() }.foregroundStyle(Theme.acc).padding(.top, 4)
        }
    }

    // MARK: helpers
    private func primaryButton(_ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity).padding(15)
                .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
                .foregroundStyle(Color(hex: 0x0E0E10))
        }
        .padding(.horizontal, 22).padding(.bottom, 14)
    }

    private func load(_ i: Int, _ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        await MainActor.run { datas[i] = data; images[i] = UIImage(data: data) }
    }

    private func startRealScan() {
        phase = .scanning
        Task {
            do {
                let inputs: [ScanAPI.ImageInput] = datas.compactMap { $0 }.prefix(3).map { d in
                    let jpeg = UIImage(data: d)?.jpegData(compressionQuality: 0.85) ?? d
                    return ScanAPI.ImageInput(mimeType: "image/jpeg", dataB64: jpeg.base64EncodedString())
                }
                // No photo → estimate a baseline from their onboarding answers.
                let result = inputs.isEmpty
                    ? try await ScanAPI.shared.estimateScan()
                    : try await ScanAPI.shared.scan(images: inputs)
                await MainActor.run { card = result; withAnimation { phase = .result } }
                // Progress-only re-scans just update the score — no (expensive) plan regen.
                if !rescan { await ScanAPI.shared.prefetchPlan() }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription; phase = .error }
            }
        }
    }

    private func reset() {
        card = nil; items = [nil, nil, nil]; images = [nil, nil, nil]; datas = [nil, nil, nil]
        includeLegs = false; showPlan = false; phase = .capture
        Task { await ScanAPI.shared.clearPlanCache() }
    }

    private func devInit() {
        guard !didDevInit else { return }
        didDevInit = true
        let env = ProcessInfo.processInfo.environment
        switch env["STETIC_FUNNEL_PHASE"] {   // dev: jump to a phase for screenshots (no sample needed)
        case "fomo": phase = .fomo
        case "focuspick": phase = .focusPick
        case "identity": phase = .identity
        case "tease": phase = .tease
        case "signin": phase = .signin
        case "trial": phase = .trialReminder
        case "paywall": phase = .paywall
        default: break
        }
        guard env["STETIC_AUTOSCAN"] == "1" || env["STETIC_LOADSAMPLE"] == "1",
              let url = Bundle.main.url(forResource: "sample", withExtension: "jpg"),
              let data = try? Data(contentsOf: url) else { return }
        datas[0] = data; images[0] = UIImage(data: data)
        if env["STETIC_AUTOSCAN"] == "1" { startRealScan() }
    }
}

// Illustrative "with vs without" diverging curves (no real numbers).
private struct WithVsWithoutChart: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            // without: drifts up slightly then flattens
            let without = curve(in: CGSize(width: w, height: h), ys: [0.55, 0.5, 0.48, 0.49, 0.5])
            // with: accelerating climb
            let with = curve(in: CGSize(width: w, height: h), ys: [0.55, 0.45, 0.34, 0.22, 0.1])
            ZStack(alignment: .topLeading) {
                // baseline grid
                Path { p in
                    for i in 0...3 { let y = h * CGFloat(i) / 3
                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y)) }
                }.stroke(Theme.line.opacity(0.5), lineWidth: 1)

                without.stroke(Theme.mut, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 5]))
                with.stroke(Theme.acc, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                with.stroke(Theme.acc.opacity(0.4), lineWidth: 8).blur(radius: 6)

                // labels
                Text("With Stetic").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.acc)
                    .position(x: w - 50, y: h * 0.1 - 2)
                Text("Without").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut)
                    .position(x: w - 42, y: h * 0.5 + 16)
            }
            .overlay(alignment: .bottom) {
                HStack { Text("Now"); Spacer(); Text("12 weeks") }
                    .font(.system(size: 10)).foregroundStyle(Theme.mut).offset(y: 16)
            }
        }
    }
    private func curve(in s: CGSize, ys: [CGFloat]) -> Path {
        Path { p in
            for (i, y) in ys.enumerated() {
                let pt = CGPoint(x: s.width * CGFloat(i) / CGFloat(ys.count - 1), y: s.height * y)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
    }
}

#Preview { RevealFunnelView(name: "Jason").preferredColorScheme(.dark) }
