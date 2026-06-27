import SwiftUI
import AVFoundation

// Intro — show what Stetic does with the real app, then "don't stay static".
// Order: comparison (aesthetics, not mass) → score → plan + progression → nutrition → with/without chart.
struct IntroView: View {
    var onDone: () -> Void
    @State private var i = Int(ProcessInfo.processInfo.environment["STETIC_INTRO_SLIDE"] ?? "") ?? 0

    // .demo plays a looping screen-recording if the .mp4 is in the bundle, else falls back to the poster screenshot.
    private enum Beat { case comparison; case shot(String); case score(String); case demo(video: String, poster: String); case chart }
    private struct Slide { let beat: Beat; let title: String; let sub: String }

    private let slides: [Slide] = [
        .init(beat: .comparison, title: "Stetic, not swole.",
              sub: "We make you look as good as possible — not just as big as possible."),
        .init(beat: .score("intro_score"), title: "Your physique, analyzed.",
              sub: "One photo → a 1–10 aesthetic score, your rank, and the weak points capping your frame."),
        .init(beat: .shot("intro_plan"), title: "A plan built on your weak points.",
              sub: "Your laggards, prioritized — the exact split and progression to bring them up."),
        .init(beat: .demo(video: "intro_log", poster: "intro_session"), title: "Every session, provably better.",
              sub: "Log your lifts — Stetic tells you when you beat last time and when to add weight."),
        .init(beat: .demo(video: "intro_food", poster: "intro_meal"), title: "Get lean without the math.",
              sub: "Scan any meal for instant calories and protein. Eat out, hit your macros, stay on track."),
        .init(beat: .chart, title: "Don't stay static.",
              sub: "People using Stetic see 3× more results in the same time."),
    ]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 10)
                visual(slides[i].beat).id("v\(i)").transition(.opacity)
                Spacer().frame(height: 22)
                VStack(spacing: 9) {
                    Text(brandLimed(slides[i].title))   // limes "Stetic" in the comparison headline
                        .font(.system(size: 27, weight: .heavy)).multilineTextAlignment(.center)
                        .foregroundStyle(Theme.txt).id("t\(i)").transition(.opacity)
                    if i == slides.count - 1 {   // "Use Stetic." sits right under "Don't stay static."
                        Text("Use Stetic.").font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(Theme.acc).padding(.top, -2)
                    }
                    Text(brandLimed(slides[i].sub))
                        .font(.system(size: 15)).multilineTextAlignment(.center).lineSpacing(3)
                        .foregroundStyle(Theme.mut).id("s\(i)").transition(.opacity)
                }
                .padding(.horizontal, 34)
                Spacer(minLength: 10)
                HStack(spacing: 7) {
                    ForEach(slides.indices, id: \.self) { k in
                        Capsule().fill(k == i ? Theme.acc : Theme.line)
                            .frame(width: k == i ? 20 : 7, height: 7).animation(.spring(response: 0.4), value: i)
                    }
                }
                .padding(.bottom, 18)
                Button { next() } label: {
                    Text(i == slides.count - 1 ? "Get started" : "Continue")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(15)
                        .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
                        .foregroundStyle(Color(hex: 0x0E0E10))
                }
                .padding(.horizontal, 22).padding(.bottom, 14)
            }
        }
    }

    private func next() {
        if i < slides.count - 1 { withAnimation(.easeInOut(duration: 0.35)) { i += 1 } } else { onDone() }
    }

    @ViewBuilder private func visual(_ beat: Beat) -> some View {
        switch beat {
        case .comparison: comparisonVisual
        case .shot(let name): shotVisual(name)
        case .score(let name): scoreVisual(name)
        case .demo(let video, let poster):
            if let url = Bundle.main.url(forResource: video, withExtension: "mp4") {
                VideoLoop(url: url)
                    .frame(width: 175, height: 374)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1))
                    .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
            } else {
                shotVisual(poster)   // no recording dropped in yet → show the still
            }
        case .chart: WithVsWithoutChart().frame(height: 230).padding(.horizontal, 30)
        }
    }

    // Mass-monster (low) vs lean aesthetic (high) — the shock factor.
    private var comparisonVisual: some View {
        HStack(spacing: 12) {
            physiqueCard("intro_mass", score: "5.2", tint: Theme.red, label: "Mass monster")
            physiqueCard("intro_aesthetic", score: "9.0", tint: Theme.acc, label: "Aesthetic")
        }
        .frame(height: 260).padding(.horizontal, 22)
    }
    private func physiqueCard(_ img: String, score: String, tint: Color, label: String) -> some View {
        // Color.clear sets the layout size; the .fill image is an overlay so it can't push the card wider.
        Color.clear
            .frame(maxWidth: .infinity).frame(height: 260)
            .overlay(Image(uiImage: UIImage(named: img) ?? UIImage()).resizable().aspectRatio(contentMode: .fill))
            .overlay(LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom))
            .overlay(alignment: .bottom) {
                VStack(spacing: 2) {
                    Text(score).font(.system(size: 30, weight: .heavy)).foregroundStyle(tint)
                    Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.txt)
                }
                .padding(.bottom, 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(tint.opacity(0.55), lineWidth: 1.5))
    }

    // A real app screen in a phone-ish frame.
    private func shotImage(_ name: String, height: CGFloat = 374) -> some View {
        Image(uiImage: UIImage(named: name) ?? UIImage()).resizable().aspectRatio(contentMode: .fit)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
    }
    private func shotVisual(_ name: String) -> some View { shotImage(name) }

    // Score slide: the card + the full rank ladder (Bronze → Greek God) so they see what they're climbing.
    private func scoreVisual(_ name: String) -> some View {
        VStack(spacing: 13) {
            shotImage(name, height: 300)
            VStack(spacing: 6) {
                Text("EVERY RANK — BRONZE TO GREEK GOD")
                    .font(.system(size: 8.5, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array(Tier.allCases.enumerated()), id: \.offset) { idx, t in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(t.color)
                                .frame(width: 20, height: 6 + CGFloat(idx) * 2.5)
                            Text(t.label).font(.system(size: 7.5, weight: .bold)).foregroundStyle(t.color)
                                .lineLimit(1).minimumScaleFactor(0.5).frame(width: 36)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
        }
    }
}

// A muted, auto-looping screen recording for the intro demo slides.
struct VideoLoop: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> LoopUIView { LoopUIView(url: url) }
    func updateUIView(_ uiView: LoopUIView, context: Context) {}
}

final class LoopUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    init(url: URL) {
        super.init(frame: .zero)
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)   // seamless loop
        player.isMuted = true
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        player.play()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

#Preview { IntroView(onDone: {}).preferredColorScheme(.dark) }
