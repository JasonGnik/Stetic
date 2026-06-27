import SwiftUI

// Intro — show what Stetic does with the real app, then "don't stay static".
// Order: comparison (aesthetics, not mass) → score → plan + progression → nutrition → with/without chart.
struct IntroView: View {
    var onDone: () -> Void
    @State private var i = Int(ProcessInfo.processInfo.environment["STETIC_INTRO_SLIDE"] ?? "") ?? 0

    private enum Beat { case comparison; case shot(String); case chart }
    private struct Slide { let beat: Beat; let title: String; let sub: String }

    private let slides: [Slide] = [
        .init(beat: .comparison, title: "Size isn't the goal.",
              sub: "Most apps just make you bigger. Stetic builds the look — lean, proportioned, athletic."),
        .init(beat: .shot("intro_score"), title: "Your physique, scored.",
              sub: "One photo → a 1–10 aesthetic score, your rank, and the weak points capping your frame."),
        .init(beat: .shot("intro_session"), title: "A plan that fixes your weak points.",
              sub: "Built around what's holding you back — and it tells you exactly when to add weight."),
        .init(beat: .shot("intro_meal"), title: "Get lean without the math.",
              sub: "Scan any meal for instant calories and protein. Eat out, hit your macros, stay on track."),
        .init(beat: .chart, title: "Don't stay static.",
              sub: "Keep guessing and you stay where you are. With Stetic, your score climbs."),
    ]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 10)
                visual(slides[i].beat).id("v\(i)").transition(.opacity)
                Spacer().frame(height: 22)
                VStack(spacing: 9) {
                    Text(slides[i].title)
                        .font(.system(size: 27, weight: .heavy)).multilineTextAlignment(.center)
                        .foregroundStyle(Theme.txt).id("t\(i)").transition(.opacity)
                    Text(brandLimed(slides[i].sub))
                        .font(.system(size: 15)).multilineTextAlignment(.center).lineSpacing(3)
                        .foregroundStyle(Theme.mut).id("s\(i)").transition(.opacity)
                    if i == slides.count - 1 {
                        Text("Use Stetic.").font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Theme.acc).padding(.top, 2).transition(.opacity)
                    }
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
    private func shotVisual(_ name: String) -> some View {
        Image(uiImage: UIImage(named: name) ?? UIImage()).resizable().aspectRatio(contentMode: .fit)
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
    }
}

#Preview { IntroView(onDone: {}).preferredColorScheme(.dark) }
