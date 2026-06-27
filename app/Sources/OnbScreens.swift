import SwiftUI

// Visual components + the identity-transformation finale for the onboarding emotional arc.
// See ONBOARDING-REDESIGN.md. Kept out of OnboardingView to stay readable.

// MARK: - Weak-point silhouette (AHA screen) — illustrative, not a real diagnosis
struct WeakPointSilhouette: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            // muted body
            Image(systemName: "figure.arms.open")
                .font(.system(size: 132, weight: .regular))
                .foregroundStyle(Theme.mut.opacity(0.35))
            // highlighted "weak point" = shoulders, glowing lime
            Circle().fill(Theme.acc.opacity(pulse ? 0.28 : 0.14))
                .frame(width: pulse ? 96 : 78, height: pulse ? 96 : 78)
                .blur(radius: 14)
                .offset(y: -34)
            HStack(spacing: 3) {
                Image(systemName: "scope").font(.system(size: 10, weight: .bold))
                Text("weak point").font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(Theme.acc)).foregroundStyle(Color(hex: 0x0E0E10))
            .offset(x: 78, y: -34)
        }
        .frame(maxWidth: .infinity)
        .onAppear { withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

// MARK: - Mountain climb (Training-fix screen) — "cover today's 25 miles, rest, go again"
struct MountainClimbView: View {
    @State private var t: CGFloat = 0
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let w = size.width, h = size.height
                // sky gradient handled by background; draw mountains
                func mountain(peakX: CGFloat, peakY: CGFloat, base: CGFloat, color: Color) {
                    var p = Path()
                    p.move(to: CGPoint(x: peakX - base, y: h))
                    p.addLine(to: CGPoint(x: peakX, y: peakY))
                    p.addLine(to: CGPoint(x: peakX + base, y: h))
                    p.closeSubpath()
                    ctx.fill(p, with: .color(color))
                }
                mountain(peakX: w * 0.32, peakY: h * 0.18, base: w * 0.5, color: Color(hex: 0x1B1B20))
                mountain(peakX: w * 0.68, peakY: h * 0.06, base: w * 0.55, color: Color(hex: 0x232329))
                // dashed switchback path
                var path = Path()
                path.move(to: CGPoint(x: w * 0.12, y: h * 0.96))
                path.addCurve(to: CGPoint(x: w * 0.68, y: h * 0.12),
                              control1: CGPoint(x: w * 0.55, y: h * 0.85),
                              control2: CGPoint(x: w * 0.35, y: h * 0.35))
                ctx.stroke(path, with: .color(Theme.acc.opacity(0.5)),
                           style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
                // hiker progressing along the path
                let frac = (sin(tl.date.timeIntervalSinceReferenceDate * 0.5) + 1) / 2
                if let pt = path.trimmedPath(from: 0, to: max(0.02, frac)).currentPoint {
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8)),
                             with: .color(Theme.acc))
                    ctx.draw(ctx.resolve(Text(Image(systemName: "figure.walk")).foregroundColor(Theme.acc).font(.system(size: 14))),
                             at: CGPoint(x: pt.x, y: pt.y - 12))
                }
            }
        }
        .background(
            LinearGradient(colors: [Color(hex: 0x121218), Color(hex: 0x0E0E10)], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
    }
}

// MARK: - Identity transformation (the finale) ⭐
struct TransformationScreen: View {
    let data: OnboardingData
    var onContinue: () -> Void
    var onBack: () -> Void

    @State private var act = 0          // 0 = trash old, 1 = become new, 2 = close
    @State private var trashed = false
    @State private var revealed = 0     // how many new-identity lines shown

    // Old self, pulled from their real answers.
    private var oldCards: [String] {
        var c: [String] = []
        let y = Int(data.timeWantedYears)
        if y >= 1 { c.append("Waited \(y) \(y == 1 ? "year" : "years")") }
        c.append(contentsOf: data.obstacles.prefix(2).map { obstacleShort($0) })
        if c.count < 3, let r = data.resultsFeeling, r == "behind" { c.append("Behind where you wanted") }
        if c.isEmpty { c = ["Spinning your wheels", "Never had a plan"] }
        return Array(c.prefix(3))
    }
    private func obstacleShort(_ id: String) -> String {
        switch id {
        case "dont_know": return "Didn't know what to do"
        case "consistent": return "Couldn't stay consistent"
        case "look_same": return "Hard work, no payoff"
        case "wasting_time": return "Wasted hours"
        case "plateau": return "Stuck at a plateau"
        case "intimidated": return "Felt lost in the gym"
        default: return "Held back"
        }
    }
    private let newIdentity = [
        "You ARE someone who sticks to the plan.",
        "You ARE consistent.",
        "You ARE efficient with your time.",
        "You work hard and do what's required — every day.",
        "One hiccup, and you're right back on track tomorrow.",
    ]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { onBack() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                    }
                    Spacer()
                }.padding(.horizontal, 22).padding(.top, 8)
                Spacer()
                Group {
                    if act == 0 { trashAct }
                    else if act == 1 { becomeAct }
                    else { closeAct }
                }
                .padding(.horizontal, 28)
                Spacer()
                cta
            }
        }
        .onAppear { runTrash() }
    }

    // ACT 1 — trash the old self
    private var trashAct: some View {
        VStack(spacing: 22) {
            Text("That's not you anymore.")
                .font(.system(size: 27, weight: .heavy)).foregroundStyle(Theme.txt).multilineTextAlignment(.center)
            VStack(spacing: 10) {
                ForEach(Array(oldCards.enumerated()), id: \.offset) { _, c in
                    Text(c).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.mut)
                        .strikethrough(trashed, color: Theme.red)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                        .opacity(trashed ? 0 : 1)
                        .offset(y: trashed ? 40 : 0)
                        .scaleEffect(trashed ? 0.9 : 1)
                }
            }
            Image(systemName: "trash.fill")
                .font(.system(size: 26)).foregroundStyle(trashed ? Theme.acc : Theme.mut.opacity(0.4))
                .scaleEffect(trashed ? 1.15 : 1)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: trashed)
    }

    // ACT 2 — you ARE this now
    private var becomeAct: some View {
        VStack(spacing: 16) {
            Text("Here's who you are now.")
                .font(.system(size: 27, weight: .heavy)).foregroundStyle(Theme.acc).multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 11) {
                ForEach(Array(newIdentity.enumerated()), id: \.offset) { i, line in
                    if i < revealed {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 16)).foregroundStyle(Theme.acc)
                            Text(brandLimed(line)).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                            Spacer(minLength: 0)
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
            }
        }
    }

    // CLOSE — Socrates + can't-buy-respect
    private var closeAct: some View {
        VStack(spacing: 16) {
            Text("“It is a shame for a man to grow old without seeing the beauty and strength of which his body is capable.”")
                .font(.system(size: 16, weight: .semibold)).italic().multilineTextAlignment(.center).lineSpacing(3)
                .foregroundStyle(Theme.txt)
            Text("— Socrates").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
            Text(brandLimed("A great physique is the one thing in life that can't be bought. No one can train or eat right for you. So it commands respect anywhere you go — living proof you set a plan and put in the work. Do that, and you can do anything. It changes how you carry every part of your life."))
                .font(.system(size: 14)).multilineTextAlignment(.center).lineSpacing(3).foregroundStyle(Theme.mut)
                .padding(.top, 4)
        }
    }

    private var cta: some View {
        Button {
            if act < 2 { withAnimation(.easeInOut) { act += 1 }; if act == 1 { runReveal() } }
            else { onContinue() }
        } label: {
            Text(act < 2 ? "Continue" : "Step into your new identity — for free")
                .font(.system(size: 16, weight: .bold)).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).padding(15)
                .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
                .foregroundStyle(Color(hex: 0x0E0E10))
        }
        .padding(.horizontal, 22).padding(.bottom, 14)
    }

    private func runTrash() {
        Task { try? await Task.sleep(nanoseconds: 1_100_000_000); await MainActor.run { trashed = true } }
    }
    private func runReveal() {
        revealed = 0
        for i in 1...newIdentity.count {
            Task {
                try? await Task.sleep(nanoseconds: UInt64(i) * 380_000_000)
                await MainActor.run { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { revealed = i } }
            }
        }
    }
}
