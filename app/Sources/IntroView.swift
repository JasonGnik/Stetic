import SwiftUI

// Cinematic intro — 4 beats: the problem, the score/rank ladder, the science/sculpt, the ascent.
struct IntroView: View {
    var onDone: () -> Void
    @State private var i = Int(ProcessInfo.processInfo.environment["STETIC_INTRO_SLIDE"] ?? "") ?? 0
    private let slides = IntroSlide.all

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                visual(i).frame(height: 250).id("v\(i)").transition(.opacity)
                Spacer().frame(height: 28)
                VStack(spacing: 12) {
                    Text(slides[i].title)
                        .font(.system(size: 28, weight: .heavy)).multilineTextAlignment(.center)
                        .foregroundStyle(Theme.txt).id("t\(i)").transition(.opacity)
                    Text(brandLimed(slides[i].sub))
                        .font(.system(size: 15)).multilineTextAlignment(.center).lineSpacing(3)
                        .foregroundStyle(Theme.mut).id("s\(i)").transition(.opacity)
                }
                .padding(.horizontal, 34)
                Spacer()
                HStack(spacing: 7) {
                    ForEach(slides.indices, id: \.self) { k in
                        Capsule().fill(k == i ? Theme.acc : Theme.line)
                            .frame(width: k == i ? 20 : 7, height: 7).animation(.spring(response: 0.4), value: i)
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
        if i < slides.count - 1 { withAnimation(.easeInOut(duration: 0.35)) { i += 1 } } else { onDone() }
    }

    @ViewBuilder private func visual(_ idx: Int) -> some View {
        switch idx {
        case 0: problemVisual
        case 1: ladderVisual
        case 2: sculptVisual
        default: ascendVisual
        }
    }

    // 0 — the problem: a body with weak points flagged
    private var problemVisual: some View {
        ZStack {
            Circle().fill(Theme.acc.opacity(0.06)).frame(width: 200, height: 200)
            Image(systemName: "figure.arms.open").font(.system(size: 78, weight: .semibold)).foregroundStyle(Theme.txt.opacity(0.8))
            Image(systemName: "viewfinder").font(.system(size: 152, weight: .ultraLight)).foregroundStyle(Theme.acc)
        }
    }

    // 1 — the rank ladder: all 8 tiers in their colors
    private var ladderVisual: some View {
        VStack(spacing: 12) {
            ForEach([Array(Tier.allCases.prefix(4)), Array(Tier.allCases.suffix(4))], id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { tier in
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 11)
                                .fill(tier.color.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 11).stroke(tier.color, lineWidth: 1.5))
                                .frame(width: 56, height: 56)
                                .overlay(Image(systemName: tier.icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(tier.color))
                            Text(tier.label).font(.system(size: 9, weight: .bold)).foregroundStyle(tier.color)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                }
            }
        }
    }

    // 2 — science / sculpt: a marble figure in an arched niche flanked by columns
    private var sculptVisual: some View {
        HStack(alignment: .bottom, spacing: 8) {
            statueColumn
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    UnevenRoundedRectangle(cornerRadii: .init(topLeading: 52, topTrailing: 52), style: .continuous)
                        .fill(Theme.card)
                        .overlay(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 52, topTrailing: 52), style: .continuous)
                            .stroke(Theme.acc.opacity(0.35), lineWidth: 1))
                        .frame(width: 104, height: 150)
                    Image(systemName: "figure.stand").font(.system(size: 92, weight: .ultraLight))
                        .foregroundStyle(Color(hex: 0xD8DCE2)).offset(y: 4)   // marble
                }
                RoundedRectangle(cornerRadius: 3).fill(Theme.line).frame(width: 124, height: 9)
                RoundedRectangle(cornerRadius: 3).fill(Theme.card).frame(width: 142, height: 9)
            }
            statueColumn
        }
        .frame(height: 230)
    }
    private var statueColumn: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(Theme.line).frame(width: 24, height: 6)
            RoundedRectangle(cornerRadius: 2).fill(Theme.card).frame(width: 15, height: 150)
            RoundedRectangle(cornerRadius: 2).fill(Theme.line).frame(width: 24, height: 7)
            Spacer().frame(height: 11)
        }
    }

    // 3 — ascend: rising bars in tier colors
    private var ascendVisual: some View {
        let tiers = Array(Tier.allCases.suffix(6))
        return HStack(alignment: .bottom, spacing: 9) {
            ForEach(Array(tiers.enumerated()), id: \.offset) { idx, tier in
                RoundedRectangle(cornerRadius: 6).fill(tier.color)
                    .frame(width: 26, height: 36 + CGFloat(idx) * 26)
                    .shadow(color: tier.color.opacity(0.5), radius: 6)
            }
            Image(systemName: "arrow.up.right").font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.acc).offset(y: -8)
        }
    }
}

struct IntroSlide {
    let title: String; let sub: String
    static let all = [
        IntroSlide(title: "Train for years.\nStill not there.",
                   sub: "Most guys can't see what's holding them back. Stetic scans your body, finds your weak points, and builds the plan to fix them."),
        IntroSlide(title: "Know exactly\nwhere you stand.",
                   sub: "Get scored 1–10 and ranked against the ideal — from Bronze all the way to Greek God."),
        IntroSlide(title: "Engineered\nto sculpt you.",
                   sub: "Your plan is built on the science of how muscle actually grows — aimed straight at the weak points breaking your frame."),
        IntroSlide(title: "Ascend.",
                   sub: "Climb the ranks, turn weak points into strengths, and walk in with confidence. Re-scan and watch it happen."),
    ]
}

#Preview { IntroView(onDone: {}).preferredColorScheme(.dark) }
