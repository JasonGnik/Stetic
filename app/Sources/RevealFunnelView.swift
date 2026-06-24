import SwiftUI
import PhotosUI

// The reveal funnel: capture the photo, build investment + FOMO with NO AI spend,
// gate the real Gemini scan behind a (stubbed) paywall, then reveal.
struct RevealFunnelView: View {
    var name: String = ""

    enum Phase { case capture, fomo, bluff, tease, paywall, scanning, result, error }
    @State private var phase: Phase = .capture
    @State private var items: [PhotosPickerItem?] = [nil, nil, nil]
    @State private var images: [UIImage?] = [nil, nil, nil]
    @State private var datas: [Data?] = [nil, nil, nil]
    @State private var includeLegs = false
    private let slotLabels = ["Front", "Side", "Back"]
    @State private var card: ScoreCard?
    @State private var errorMsg = ""
    @State private var showPlan = false
    @State private var didDevInit = false
    @State private var selectedPlan = "annual"   // annual | weekly

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            switch phase {
            case .capture:  capture
            case .fomo:     fomo
            case .bluff:    bluff
            case .tease:    tease
            case .paywall:  paywall
            case .scanning: scanningView
            case .result:   resultView
            case .error:    errorView
            }
        }
        .task { devInit() }
    }

    private var hasAnyPhoto: Bool { datas.contains { $0 != nil } }

    // MARK: capture — front is the main shot (larger), side/back optional. Any one unlocks the scan.
    private var capture: some View {
        VStack(spacing: 18) {
            Spacer()
            VStack(spacing: 6) {
                Text("STETIC").font(.system(size: 30, weight: .heavy)).tracking(3).foregroundStyle(Theme.acc)
                Text("Scan your physique").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.mut)
            }
            VStack(spacing: 10) {
                photoSlot(0, height: 210, main: true)
                HStack(spacing: 10) {
                    photoSlot(1, height: 132)
                    photoSlot(2, height: 132)
                }
            }
            .padding(.horizontal, 22)

            Toggle(isOn: $includeLegs) {
                Text("Include legs (full-body score)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
            }
            .tint(Theme.acc).padding(.horizontal, 26)

            Text(includeLegs ? "Stand back so your legs are in frame."
                             : "Add at least one. Front is most accurate — side & back sharpen it.")
                .font(.system(size: 12)).foregroundStyle(Theme.mut).multilineTextAlignment(.center).padding(.horizontal, 30)

            Button { withAnimation { phase = .fomo } } label: {
                Text("Continue").font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(hasAnyPhoto ? Theme.acc : Theme.line))
                    .foregroundStyle(hasAnyPhoto ? Color(hex: 0x0E0E10) : Theme.mut)
            }
            .disabled(!hasAnyPhoto)
            .padding(.horizontal, 26)
            Spacer()
        }
        .onChange(of: items[0]) { _, v in Task { await load(0, v) } }
        .onChange(of: items[1]) { _, v in Task { await load(1, v) } }
        .onChange(of: items[2]) { _, v in Task { await load(2, v) } }
    }

    private func photoSlot(_ i: Int, height: CGFloat, main: Bool = false) -> some View {
        PhotosPicker(selection: $items[i], matching: .images) {
            ZStack {
                if let img = images[i] {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Theme.card
                    VStack(spacing: 6) {
                        Image(systemName: main ? "person.crop.rectangle" : "plus")
                            .font(.system(size: main ? 30 : 20, weight: .semibold)).foregroundStyle(main ? Theme.acc : Theme.mut)
                        Text(slotLabels[i]).font(.system(size: main ? 15 : 12, weight: .semibold)).foregroundStyle(Theme.txt)
                        Text(main ? "main shot" : "optional").font(.system(size: main ? 11 : 9)).foregroundStyle(Theme.mut)
                    }
                }
            }
            .frame(height: height).frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(main && images[i] == nil ? Theme.acc.opacity(0.45) : Theme.line, lineWidth: 1))
        }
    }

    // MARK: FOMO — with vs without (illustrative, no real scores yet)
    private var fomo: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 10) {
                Text("THE NEXT 12 WEEKS").font(.system(size: 11, weight: .bold)).tracking(2).foregroundStyle(Theme.mut)
                Text(brandLimed("Don't stay static.\nUse Stetic."))
                    .font(.system(size: 28, weight: .heavy)).multilineTextAlignment(.center).foregroundStyle(Theme.txt)
            }
            WithVsWithoutChart().frame(height: 220).padding(.horizontal, 30).padding(.top, 24)
            Text(brandLimed("Most guys plateau — they train without a plan built on their weak points and leave their potential on the table. Stetic changes the line."))
                .font(.system(size: 14)).multilineTextAlignment(.center).lineSpacing(4)
                .foregroundStyle(Theme.mut).padding(.horizontal, 34).padding(.top, 22)
            Spacer()
            primaryButton("See my potential") { withAnimation { phase = .bluff } }
        }
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
                if phase == .bluff { withAnimation { phase = .tease } }
            }
        }
    }

    // MARK: tease — blurred result behind a lock
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
                primaryButton("Unlock my results") { withAnimation { phase = .paywall } }
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

    // MARK: paywall (STUB — swap for RevenueCat later)
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
                        (Text("Unlock ").font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.txt)
                         + Text("Stetic").font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.acc))
                        Text("Everything you need to ascend.").font(.system(size: 14)).foregroundStyle(Theme.mut)
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
                        planRow("annual", "Annual", "$1.15", "/wk", "$59.99/yr · 3-day free trial", best: true)
                        planRow("weekly", "Weekly", "$9.99", "/wk", "Billed weekly", best: false)
                    }
                    .padding(.horizontal, 22).padding(.top, 24)
                }
            }
            .scrollIndicators(.hidden)

            primaryButton(selectedPlan == "annual" ? "Start my 3-day free trial" : "Continue with weekly") { startRealScan() }
            Text(paywallTerms)
                .font(.system(size: 10.5)).multilineTextAlignment(.center).foregroundStyle(Theme.mut)
                .padding(.horizontal, 30).padding(.top, 2).padding(.bottom, 6)
            Text("Restore purchases").font(.system(size: 12)).foregroundStyle(Theme.mut).padding(.bottom, 12)
        }
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
            title: "Scoring your aesthetics",
            messages: ["Sending to the model", "Scoring leanness & proportion",
                       "Ranking your muscle groups", "Computing your aesthetic score", "Finalizing"],
            icons: ["bolt.fill", "drop.fill", "list.number", "star.fill", "checkmark.seal.fill"]
        )
    }

    private var resultView: some View {
        Group {
            if let card {
                ScoreCardView(card: card, onGetPlan: { showPlan = true })
                    .fullScreenCover(isPresented: $showPlan) { PlanView() }
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
                guard !inputs.isEmpty else { throw APIError.decode }
                let result = try await ScanAPI.shared.scan(images: inputs)
                await MainActor.run { card = result; withAnimation { phase = .result } }
                await ScanAPI.shared.prefetchPlan()   // ready before they tap "Get my full plan"
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
        guard env["STETIC_AUTOSCAN"] == "1" || env["STETIC_LOADSAMPLE"] == "1",
              let url = Bundle.main.url(forResource: "sample", withExtension: "jpg"),
              let data = try? Data(contentsOf: url) else { return }
        datas[0] = data; images[0] = UIImage(data: data)
        if env["STETIC_AUTOSCAN"] == "1" { startRealScan() }
        switch env["STETIC_FUNNEL_PHASE"] {   // dev: jump to a phase for screenshots
        case "fomo": phase = .fomo
        case "tease": phase = .tease
        case "paywall": phase = .paywall
        default: break
        }
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
