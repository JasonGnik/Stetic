import SwiftUI
import PhotosUI

// The reveal funnel: capture the photo, build investment + FOMO with NO AI spend,
// gate the real Gemini scan behind a (stubbed) paywall, then reveal.
struct RevealFunnelView: View {
    var name: String = ""

    enum Phase { case capture, fomo, bluff, tease, paywall, scanning, result, error }
    @State private var phase: Phase = .capture
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var uiImage: UIImage?
    @State private var card: ScoreCard?
    @State private var errorMsg = ""
    @State private var showPlan = false
    @State private var didDevInit = false

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

    // MARK: capture
    private var capture: some View {
        VStack(spacing: 22) {
            Spacer()
            VStack(spacing: 6) {
                Text("STETIC").font(.system(size: 30, weight: .heavy)).tracking(3).foregroundStyle(Theme.acc)
                Text("Scan your physique").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.mut)
            }
            ZStack {
                if let uiImage { Image(uiImage: uiImage).resizable().scaledToFill() }
                else {
                    Theme.card
                    VStack(spacing: 10) {
                        Image(systemName: "figure.arms.open").font(.system(size: 44)).foregroundStyle(Theme.mut)
                        Text("Front-facing · athletic wear · good lighting")
                            .font(.system(size: 12)).foregroundStyle(Theme.mut)
                            .multilineTextAlignment(.center).padding(.horizontal, 24)
                    }
                }
            }
            .frame(width: 250, height: 330)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1))

            VStack(spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text(uiImage == nil ? "Choose photo" : "Choose different photo")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                        .frame(maxWidth: .infinity).padding(13)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                }
                Button { withAnimation { phase = .fomo } } label: {
                    Text("Continue").font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(uiImage == nil ? Theme.line : Theme.acc))
                        .foregroundStyle(uiImage == nil ? Theme.mut : Color(hex: 0x0E0E10))
                }
                .disabled(uiImage == nil)
            }
            .padding(.horizontal, 28)
            Spacer()
        }
        .onChange(of: pickerItem) { _, item in Task { await load(item) } }
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
            ScoreCardView(card: .sample).blur(radius: 24).disabled(true).allowsHitTesting(false)
            LinearGradient(colors: [Theme.bg.opacity(0.7), Theme.bg.opacity(0.96)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "lock.fill").font(.system(size: 34)).foregroundStyle(Theme.acc)
                Text(name.isEmpty ? "Your analysis is ready" : "\(name), your analysis is ready")
                    .font(.system(size: 24, weight: .heavy)).multilineTextAlignment(.center).foregroundStyle(Theme.txt)
                    .padding(.horizontal, 30)
                Text("We mapped your physique and found 3 lagging groups and 1 proportion breaking your frame. Unlock your score, rank, and plan.")
                    .font(.system(size: 14)).multilineTextAlignment(.center).lineSpacing(4)
                    .foregroundStyle(Theme.mut).padding(.horizontal, 34)
                Spacer()
                primaryButton("Unlock my results") { withAnimation { phase = .paywall } }
            }
        }
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
                        planRow("Annual", "$119.99/yr", "($2.30/wk)", "3-day free trial, then yearly", best: true)
                        planRow("Weekly", "$7.99/wk", nil, "Billed weekly. Cancel anytime.", best: false)
                    }
                    .padding(.horizontal, 22).padding(.top, 24)
                }
            }
            .scrollIndicators(.hidden)

            Text("No payment now. 3-day free trial, then $119.99/year. Auto-renews unless cancelled 24h before the trial ends. Cancel anytime in Settings.")
                .font(.system(size: 10.5)).multilineTextAlignment(.center).foregroundStyle(Theme.mut)
                .padding(.horizontal, 30).padding(.top, 10).padding(.bottom, 8)
            primaryButton("Start my 3-day free trial") { startRealScan() }
            Text("Restore purchases").font(.system(size: 12)).foregroundStyle(Theme.mut).padding(.bottom, 12)
        }
    }

    private func planRow(_ title: String, _ price: String, _ subprice: String?, _ detail: String, best: Bool) -> some View {
        HStack {
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
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(price).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                if let subprice { Text(subprice).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.acc) }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(best ? Theme.acc.opacity(0.08) : Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(best ? Theme.acc : Theme.line, lineWidth: best ? 1.5 : 1))
        )
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
                ScoreCardView(card: card, onGetPlan: { showPlan = true }, onScanAnother: { reset() })
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

    private func load(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        imageData = data; uiImage = UIImage(data: data)
    }

    private func startRealScan() {
        phase = .scanning
        Task {
            do {
                guard let data = imageData else { throw APIError.decode }
                let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.85) ?? data
                let input = ScanAPI.ImageInput(mimeType: "image/jpeg", dataB64: jpeg.base64EncodedString())
                let result = try await ScanAPI.shared.scan(images: [input])
                await MainActor.run { card = result; withAnimation { phase = .result } }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription; phase = .error }
            }
        }
    }

    private func reset() {
        card = nil; uiImage = nil; imageData = nil; pickerItem = nil; showPlan = false; phase = .capture
    }

    private func devInit() {
        guard !didDevInit else { return }
        didDevInit = true
        let env = ProcessInfo.processInfo.environment
        guard env["STETIC_AUTOSCAN"] == "1" || env["STETIC_LOADSAMPLE"] == "1",
              let url = Bundle.main.url(forResource: "sample", withExtension: "jpg"),
              let data = try? Data(contentsOf: url) else { return }
        imageData = data; uiImage = UIImage(data: data)
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
