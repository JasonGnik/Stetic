import SwiftUI

// Cinematic intro — leads with the "gotcha" (scan → score), then 3 feature beats.
struct IntroView: View {
    var onDone: () -> Void
    @State private var i = 0
    private let slides = IntroSlide.all

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Circle().fill(Theme.acc.opacity(0.08)).frame(width: 190, height: 190)
                    Circle().stroke(Theme.acc.opacity(0.25), lineWidth: 1).frame(width: 190, height: 190)
                    Image(systemName: slides[i].icon)
                        .font(.system(size: 70, weight: .semibold))
                        .foregroundStyle(Theme.acc)
                        .id("ic\(i)")
                        .transition(.scale.combined(with: .opacity))
                }
                .frame(height: 230)

                Spacer().frame(height: 30)
                VStack(spacing: 12) {
                    Text(slides[i].title)
                        .font(.system(size: 28, weight: .heavy))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.txt)
                        .id("t\(i)")
                        .transition(.opacity)
                    Text(brandLimed(slides[i].sub))
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .foregroundStyle(Theme.mut)
                        .id("s\(i)")
                        .transition(.opacity)
                }
                .padding(.horizontal, 36)

                Spacer()
                HStack(spacing: 7) {
                    ForEach(slides.indices, id: \.self) { k in
                        Capsule().fill(k == i ? Theme.acc : Theme.line)
                            .frame(width: k == i ? 20 : 7, height: 7)
                            .animation(.spring(response: 0.4), value: i)
                    }
                }
                .padding(.bottom, 22)
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
        if i < slides.count - 1 { withAnimation(.easeInOut(duration: 0.35)) { i += 1 } }
        else { onDone() }
    }
}

struct IntroSlide {
    let icon: String; let title: String; let sub: String
    static let all = [
        IntroSlide(icon: "viewfinder",
                   title: "Scan your body.\nGet your real score.",
                   sub: "The naked eye misses the patterns. Stetic finds them — powered by computer vision."),
        IntroSlide(icon: "rosette",
                   title: "Your score & rank",
                   sub: "Rated 1–10 and ranked against the ideal — from Bronze all the way to Greek God."),
        IntroSlide(icon: "dumbbell.fill",
                   title: "A plan for your weak points",
                   sub: "Built on proven high-intensity principles — around exactly what's holding you back."),
        IntroSlide(icon: "chart.line.uptrend.xyaxis",
                   title: "Watch yourself climb",
                   sub: "Re-scan anytime and watch your score rise. The aesthetic glow-up, gamified."),
    ]
}

#Preview { IntroView(onDone: {}).preferredColorScheme(.dark) }
