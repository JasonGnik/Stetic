import SwiftUI

// Visual components + the identity-transformation finale for the onboarding emotional arc.
// See ONBOARDING-REDESIGN.md. Kept out of OnboardingView to stay readable.

// MARK: - Weak-point silhouette (AHA screen) — a "mock scan": figure + sweeping scan line + lit weak point.
struct WeakPointSilhouette: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let p = (tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.4)) / 3.4
            Canvas { ctx, size in draw(&ctx, size, p) }
        }
        .frame(maxWidth: .infinity)
    }
    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ p: Double) {
        let w = size.width, h = size.height, cx = w/2
        let mut = Color(hex: 0x595961)
        func cap(_ x: CGFloat, _ y: CGFloat, _ ww: CGFloat, _ hh: CGFloat, _ c: Color) {
            ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: ww, height: hh), cornerSize: CGSize(width: ww/2, height: ww/2)), with: .color(c))
        }
        // glow behind shoulders
        ctx.fill(Path(ellipseIn: CGRect(x: cx-46, y: 18, width: 92, height: 58)), with: .color(Theme.acc.opacity(0.16)))
        // body (muted)
        cap(cx-42, 42, 11, 58, mut); cap(cx+31, 42, 11, 58, mut)       // arms
        cap(cx-16, 86, 13, 56, mut); cap(cx+3, 86, 13, 56, mut)        // legs
        ctx.fill(Path(ellipseIn: CGRect(x: cx-10, y: 6, width: 20, height: 20)), with: .color(mut))   // head
        var torso = Path()
        torso.move(to: CGPoint(x: cx-28, y: 42)); torso.addLine(to: CGPoint(x: cx+28, y: 42))
        torso.addLine(to: CGPoint(x: cx+14, y: 92)); torso.addLine(to: CGPoint(x: cx-14, y: 92)); torso.closeSubpath()
        ctx.fill(torso, with: .color(mut))
        // shoulders = lit weak point
        ctx.fill(Path(ellipseIn: CGRect(x: cx-48, y: 30, width: 36, height: 26)), with: .color(Theme.acc))
        ctx.fill(Path(ellipseIn: CGRect(x: cx+12, y: 30, width: 36, height: 26)), with: .color(Theme.acc))
        // sweeping scan line + trailing band
        let sy = 6 + (h-12) * p
        ctx.fill(Path(CGRect(x: 10, y: sy, width: w-20, height: 18)),
                 with: .linearGradient(Gradient(colors: [Theme.acc.opacity(0.16), .clear]), startPoint: CGPoint(x: 0, y: sy), endPoint: CGPoint(x: 0, y: sy+18)))
        ctx.fill(Path(CGRect(x: 10, y: sy-1, width: w-20, height: 2)), with: .color(Theme.acc.opacity(0.85)))
        // scan-frame corner brackets
        let L: CGFloat = 14, m: CGFloat = 6
        for (ox, oy, sxn, syn) in [(m, m, 1.0, 1.0), (w-m, m, -1.0, 1.0), (m, h-m, 1.0, -1.0), (w-m, h-m, -1.0, -1.0)] {
            var b = Path()
            b.move(to: CGPoint(x: ox + L*sxn, y: oy)); b.addLine(to: CGPoint(x: ox, y: oy)); b.addLine(to: CGPoint(x: ox, y: oy + L*syn))
            ctx.stroke(b, with: .color(Theme.acc.opacity(0.7)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        // weak-point tag
        let tag = CGRect(x: cx+44, y: 26, width: 58, height: 18)
        ctx.fill(Path(roundedRect: tag, cornerSize: CGSize(width: 9, height: 9)), with: .color(Theme.acc))
        ctx.draw(ctx.resolve(Text("weak point").font(.system(size: 9.5, weight: .bold)).foregroundColor(Color(hex: 0x0E0E10))), at: CGPoint(x: tag.midX, y: tag.midY))
    }
}

// Blend two 0xRRGGBB colors.
func blendHex(_ a: Int, _ b: Int, _ t: Double) -> Color {
    let tt = max(0, min(1, t))
    func ch(_ x: Int, _ sh: Int) -> Double { Double((x >> sh) & 0xFF) }
    let r = ch(a,16) + (ch(b,16) - ch(a,16)) * tt
    let g = ch(a,8)  + (ch(b,8)  - ch(a,8))  * tt
    let bl = ch(a,0) + (ch(b,0)  - ch(a,0))  * tt
    return Color(red: r/255, green: g/255, blue: bl/255)
}

// MARK: - Mountain climb (Training-fix screen) — cinematic day→dusk cycle.
// One looping "day": dawn → hiker walks up to camp → dusk → night (rests by a fire) → repeat.
// The message: don't stare at the summit; just do today's stretch, rest, go again.
struct MountainClimbView: View {
    private let dayLength: Double = 13

    var body: some View {
        TimelineView(.animation) { tl in
            let p = (tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: dayLength)) / dayLength
            Canvas { ctx, size in draw(&ctx, size, p) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ p: Double) {
        let w = size.width, h = size.height
        let dayProg = min(p, 0.62) / 0.62
        let daylight = max(0, sin(dayProg * .pi))
        let night = p >= 0.62
        let glow = night ? 0 : max(0, 1 - abs(dayProg - 0.5) * 2.2)

        let top = blendHex(0x0A0A12, 0x15263B, daylight * 0.85)
        let bottom = night ? blendHex(0x0E0E10, 0x14141C, 0.6) : blendHex(0x12100E, 0x21381F, daylight)
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)),
                 with: .linearGradient(Gradient(colors: [top, bottom]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        if glow > 0.05 {
            ctx.fill(Path(CGRect(x: 0, y: h*0.45, width: w, height: h*0.55)),
                     with: .linearGradient(Gradient(colors: [blendHex(0xFF7A1A, 0xC8FF4D, 0.4).opacity(glow*0.35), .clear]),
                                           startPoint: CGPoint(x: 0, y: h), endPoint: CGPoint(x: 0, y: h*0.45)))
        }
        if night {
            let fade = min(1, (p - 0.62) / 0.12)
            for s in [(0.18,0.16),(0.34,0.27),(0.52,0.12),(0.7,0.22),(0.84,0.14),(0.26,0.4),(0.62,0.36)] {
                ctx.fill(Path(ellipseIn: CGRect(x: w*s.0, y: h*s.1, width: 1.6, height: 1.6)), with: .color(.white.opacity(0.5*fade)))
            }
        }
        let celX = w * (0.12 + dayProg * 0.76)
        let celY = h * (0.62 - daylight * 0.46)
        if night {
            let mx = w*0.74, my = h*0.2
            ctx.fill(Path(ellipseIn: CGRect(x: mx-9, y: my-9, width: 18, height: 18)), with: .color(.white.opacity(0.85)))
            ctx.fill(Path(ellipseIn: CGRect(x: mx-4, y: my-11, width: 16, height: 16)), with: .color(bottom))
        } else {
            ctx.fill(Path(ellipseIn: CGRect(x: celX-22, y: celY-22, width: 44, height: 44)), with: .color(blendHex(0xFFB24A, 0xC8FF4D, daylight).opacity(0.18)))
            ctx.fill(Path(ellipseIn: CGRect(x: celX-9, y: celY-9, width: 18, height: 18)), with: .color(blendHex(0xFFB24A, 0xEFFFAE, daylight)))
        }
        func mtn(_ peakX: CGFloat, _ peakY: CGFloat, _ base: CGFloat, _ color: Color) {
            var pa = Path()
            pa.move(to: CGPoint(x: peakX - base, y: h)); pa.addLine(to: CGPoint(x: peakX, y: peakY)); pa.addLine(to: CGPoint(x: peakX + base, y: h)); pa.closeSubpath()
            ctx.fill(pa, with: .color(color))
        }
        let shade = night ? 0.0 : daylight * 0.10
        mtn(w*0.30, h*0.20, w*0.52, blendHex(0x191920, 0x22323A, shade))
        mtn(w*0.72, h*0.07, w*0.58, blendHex(0x111118, 0x1A2730, shade))
        ctx.fill(Path(CGRect(x: 0, y: h*0.86, width: w, height: h*0.14)), with: .color(blendHex(0x0C0C10, 0x12180F, shade)))

        let sx = w*0.72, sy = h*0.07
        ctx.stroke(Path { $0.move(to: CGPoint(x: sx, y: sy)); $0.addLine(to: CGPoint(x: sx, y: sy-16)) }, with: .color(.white.opacity(0.85)), lineWidth: 1.5)
        ctx.fill(Path { $0.move(to: CGPoint(x: sx, y: sy-16)); $0.addLine(to: CGPoint(x: sx+13, y: sy-12)); $0.addLine(to: CGPoint(x: sx, y: sy-8)) }, with: .color(Theme.acc))

        let camp = CGPoint(x: w*0.5, y: h*0.5)
        var path = Path()
        path.move(to: CGPoint(x: w*0.14, y: h*0.9))
        path.addCurve(to: camp, control1: CGPoint(x: w*0.42, y: h*0.84), control2: CGPoint(x: w*0.26, y: h*0.6))
        ctx.stroke(path, with: .color(Theme.acc.opacity(0.45)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 5]))

        if night {
            ctx.fill(Path { $0.move(to: CGPoint(x: camp.x-12, y: camp.y)); $0.addLine(to: CGPoint(x: camp.x-2, y: camp.y-13)); $0.addLine(to: CGPoint(x: camp.x+8, y: camp.y)); $0.closeSubpath() }, with: .color(Color(hex: 0x2A2A30)))
            let flick = 0.7 + 0.3 * sin(p * 60)
            ctx.fill(Path(ellipseIn: CGRect(x: camp.x+11, y: camp.y-7, width: 12*flick, height: 14*flick)), with: .color(blendHex(0xFF7A1A, 0xC8FF4D, 0.3).opacity(0.9)))
            ctx.fill(Path(ellipseIn: CGRect(x: camp.x+13, y: camp.y-4, width: 6, height: 8)), with: .color(blendHex(0xFFD27A, 0xEFFFAE, 0.4)))
        } else if let pt = path.trimmedPath(from: 0, to: max(0.04, dayProg)).currentPoint {
            ctx.draw(ctx.resolve(Text(Image(systemName: "figure.walk")).foregroundColor(Theme.acc).font(.system(size: 15, weight: .bold))), at: CGPoint(x: pt.x, y: pt.y - 9))
        }
    }
}

// MARK: - Identity transformation (the finale) ⭐
struct TransformationScreen: View {
    let data: OnboardingData
    var onContinue: () -> Void
    var onBack: () -> Void

    @State private var act = 0          // 0 = trash old, 1 = become new, 2 = close
    @State private var trashPhase = 0   // 0 shown, 1 falling, 2 embers
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

    // ACT 1 — trash the old self, then burn it. trashPhase: 0 shown · 1 falling into bin · 2 embers.
    private var trashAct: some View {
        VStack(spacing: 20) {
            Text("That's not you anymore.")
                .font(.system(size: 27, weight: .heavy)).foregroundStyle(Theme.txt).multilineTextAlignment(.center)
            VStack(spacing: 10) {
                ForEach(Array(oldCards.enumerated()), id: \.offset) { i, c in
                    Text(c).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.mut)
                        .strikethrough(trashPhase >= 1, color: Theme.red)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                        .opacity(trashPhase == 0 ? 1 : 0)
                        .offset(y: trashPhase == 0 ? 0 : 150)
                        .scaleEffect(trashPhase == 0 ? 1 : 0.5)
                        .rotationEffect(.degrees(trashPhase == 0 ? 0 : (i % 2 == 0 ? 14 : -12)))
                        .animation(.easeIn(duration: 0.7).delay(Double(i) * 0.08), value: trashPhase)
                }
            }
            ZStack {
                if trashPhase >= 2 { EmberBurst().frame(width: 90, height: 64).offset(y: -10) }
                Image(systemName: "trash.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(trashPhase >= 1 ? Theme.acc : Theme.mut.opacity(0.4))
                    .scaleEffect(trashPhase == 1 ? 1.2 : 1)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: trashPhase)
            }
            .frame(height: 70)
        }
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
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run { trashPhase = 1 }                 // cards fall into the bin
            try? await Task.sleep(nanoseconds: 750_000_000)
            await MainActor.run { withAnimation(.easeOut(duration: 0.3)) { trashPhase = 2 } }   // burn
        }
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

// MARK: - "How it works" auto-play demo (replaces the AHA generic figure)
// Four beats with mini real-app mockups: scan → weak points → plan → progress.
struct HowItWorksDemo: View {
    @State private var beat = 0
    private let beats = 4
    private let titles = ["First, we scan your physique.", "We pinpoint your weak points.",
                          "Your plan targets them.", "Then brings them up — week after week."]
    private let subs = ["One photo → a real score and a read of your frame.",
                        "The one or two lagging areas breaking your look.",
                        "Built around fixing them — not junk volume.",
                        "Re-scan and watch the gap close."]
    var body: some View {
        VStack(spacing: 16) {
            ZStack { card }.frame(height: 226)
            HStack(spacing: 6) {
                ForEach(0..<beats, id: \.self) { i in
                    Capsule().fill(i == beat ? Theme.acc : Theme.line)
                        .frame(width: i == beat ? 18 : 6, height: 6)
                        .animation(.spring(response: 0.3), value: beat)
                }
            }
            VStack(spacing: 6) {
                Text(titles[beat]).font(.system(size: 21, weight: .heavy)).multilineTextAlignment(.center).foregroundStyle(Theme.txt)
                Text(subs[beat]).font(.system(size: 13.5)).multilineTextAlignment(.center).foregroundStyle(Theme.mut).lineSpacing(2)
            }
            .id(beat).transition(.opacity)
        }
        .onAppear { run() }
    }
    private var card: some View {
        Group {
            switch beat {
            case 0: scanMini
            case 1: weakMini
            case 2: planMini
            default: progressMini
            }
        }
        .padding(15).frame(width: 252, height: 226)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: 0x121214))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 1)))
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .id(beat)
    }
    private var scanMini: some View {
        VStack(spacing: 9) {
            Text("STETIC SCORE").font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(Theme.mut)
            ZStack {
                PhysiqueFigure(tint: Color(hex: 0x55555D), lean: true).frame(width: 56, height: 92)
                Rectangle().fill(Theme.acc.opacity(0.85)).frame(width: 96, height: 2)
                ForEach(0..<4) { i in
                    let c: [CGFloat] = [-48, 48, -48, 48], d: [CGFloat] = [-46, -46, 46, 46]
                    Path { p in p.move(to: .init(x: 8, y: 0)); p.addLine(to: .init(x: 0, y: 0)); p.addLine(to: .init(x: 0, y: 8)) }
                        .stroke(Theme.acc.opacity(0.7), lineWidth: 2)
                        .scaleEffect(x: i % 2 == 0 ? 1 : -1, y: i < 2 ? 1 : -1).offset(x: c[i], y: d[i])
                }
            }.frame(height: 104)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("7.2").font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.txt)
                Text("/10").font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
        }
    }
    private var weakMini: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("YOUR FRAME").font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(Theme.mut)
            bar("Chest", 0.82, false); bar("Arms", 0.74, false)
            bar("Shoulders", 0.4, true); bar("Back", 0.46, true)
            bar("Legs", 0.7, false); bar("Abs", 0.66, false)
        }
    }
    private func bar(_ name: String, _ frac: CGFloat, _ weak: Bool) -> some View {
        HStack(spacing: 8) {
            Text(name).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.txt).frame(width: 62, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line).frame(height: 6)
                    Capsule().fill(weak ? Theme.red : Theme.acc).frame(width: g.size.width * frac, height: 6)
                }
            }.frame(height: 6)
            Text(weak ? "weak" : "").font(.system(size: 8.5, weight: .bold)).foregroundStyle(Theme.red).frame(width: 28, alignment: .leading)
        }
    }
    private var planMini: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR PLAN · PUSH").font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(Theme.mut)
            planRow("Incline DB Press", "2 × 5–9", false)
            planRow("Lateral Raise", "2 × 12–15", true)
            planRow("Cable Lateral", "2 × 15–20", true)
            planRow("Triceps Pushdown", "2 × 10–12", false)
        }
    }
    private func planRow(_ name: String, _ sr: String, _ weak: Bool) -> some View {
        HStack(spacing: 8) {
            Circle().fill(weak ? Theme.red : Theme.acc).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt)
                if weak { Text("weak point").font(.system(size: 8.5, weight: .bold)).foregroundStyle(Theme.red) }
            }
            Spacer()
            Text(sr).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut)
        }
        .padding(.vertical, 5).padding(.horizontal, 9)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color(hex: 0x17171A)))
    }
    private var progressMini: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR CLIMB").font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(Theme.mut)
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let pts = [CGPoint(x: 0, y: h*0.82), CGPoint(x: w*0.34, y: h*0.6), CGPoint(x: w*0.66, y: h*0.34), CGPoint(x: w, y: h*0.12)]
                var area = Path(); area.move(to: CGPoint(x: 0, y: h)); pts.forEach { area.addLine(to: $0) }; area.addLine(to: CGPoint(x: w, y: h)); area.closeSubpath()
                ctx.fill(area, with: .color(Theme.acc.opacity(0.12)))
                var line = Path(); line.move(to: pts[0]); pts.dropFirst().forEach { line.addLine(to: $0) }
                ctx.stroke(line, with: .color(Theme.acc), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                ctx.fill(Path(ellipseIn: CGRect(x: pts.last!.x-5, y: pts.last!.y-5, width: 10, height: 10)), with: .color(Theme.acc))
            }.frame(height: 116)
            HStack {
                Text("Week 1").font(.system(size: 10)).foregroundStyle(Theme.mut)
                Spacer()
                Text("Week 12  ").font(.system(size: 10)).foregroundStyle(Theme.mut)
                Text("+1.8").font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.acc)
            }
        }
    }
    private func run() {
        Task {
            for b in 1..<beats {
                try? await Task.sleep(nanoseconds: 2_300_000_000)
                await MainActor.run { withAnimation(.easeInOut(duration: 0.45)) { beat = b } }
            }
        }
    }
}

// Reusable composed-shape physique figure (used by the demo + before/after).
struct PhysiqueFigure: View {
    var tint: Color
    var lean: Bool
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height, cx = w/2
            func cap(_ x: CGFloat, _ y: CGFloat, _ ww: CGFloat, _ hh: CGFloat) {
                ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: ww, height: hh), cornerSize: CGSize(width: ww/2, height: ww/2)), with: .color(tint))
            }
            let shoulder: CGFloat = lean ? w*0.34 : w*0.25, waist: CGFloat = lean ? w*0.15 : w*0.24
            ctx.fill(Path(ellipseIn: CGRect(x: cx-w*0.1, y: h*0.04, width: w*0.2, height: w*0.2)), with: .color(tint))
            cap(cx-shoulder-w*0.1, h*0.26, w*0.11, h*0.42); cap(cx+shoulder-w*0.01, h*0.26, w*0.11, h*0.42)
            cap(cx-w*0.17, h*0.62, w*0.13, h*0.36); cap(cx+w*0.04, h*0.62, w*0.13, h*0.36)
            var torso = Path()
            torso.move(to: CGPoint(x: cx-shoulder, y: h*0.26)); torso.addLine(to: CGPoint(x: cx+shoulder, y: h*0.26))
            torso.addLine(to: CGPoint(x: cx+waist, y: h*0.64)); torso.addLine(to: CGPoint(x: cx-waist, y: h*0.64)); torso.closeSubpath()
            ctx.fill(torso, with: .color(tint))
        }
    }
}

// MARK: - Before → after physique (projection payoff in the funnel)
// Illustrative (pre-scan): a soft "now" figure → a lean, defined "potential" figure.
struct BeforeAfterPhysique: View {
    var nowLabel: String = "Now"
    var afterLabel: String = "12 weeks"
    var body: some View {
        HStack(spacing: 16) {
            figureCol(nowLabel, "soft, undefined", tint: Color(hex: 0x5A5A62), lean: false)
            Image(systemName: "arrow.right").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.acc)
            figureCol(afterLabel, "lean, complete", tint: Theme.acc, lean: true)
        }
    }
    private func figureCol(_ title: String, _ sub: String, tint: Color, lean: Bool) -> some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in drawFigure(&ctx, size, tint: tint, lean: lean) }
                .frame(width: 92, height: 132)
            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(lean ? Theme.acc : Theme.txt)
            Text(sub).font(.system(size: 10.5)).foregroundStyle(Theme.mut)
        }
    }
    private func drawFigure(_ ctx: inout GraphicsContext, _ size: CGSize, tint: Color, lean: Bool) {
        let w = size.width, h = size.height, cx = w/2
        func cap(_ x: CGFloat, _ y: CGFloat, _ ww: CGFloat, _ hh: CGFloat) {
            ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: ww, height: hh), cornerSize: CGSize(width: ww/2, height: ww/2)), with: .color(tint))
        }
        let shoulder: CGFloat = lean ? 30 : 22
        let waist: CGFloat = lean ? 13 : 21
        ctx.fill(Path(ellipseIn: CGRect(x: cx-9, y: 6, width: 18, height: 18)), with: .color(tint))   // head
        cap(cx-shoulder-9, 34, 10, 56); cap(cx+shoulder-1, 34, 10, 56)                                  // arms
        cap(cx-15, h-54, 12, 52); cap(cx+3, h-54, 12, 52)                                               // legs
        var torso = Path()
        torso.move(to: CGPoint(x: cx-shoulder, y: 34)); torso.addLine(to: CGPoint(x: cx+shoulder, y: 34))
        torso.addLine(to: CGPoint(x: cx+waist, y: h-56)); torso.addLine(to: CGPoint(x: cx-waist, y: h-56)); torso.closeSubpath()
        ctx.fill(torso, with: .color(tint))
        if lean {   // definition lines on the lean figure
            let dark = Color(hex: 0x0E0E10).opacity(0.5)
            ctx.stroke(Path { $0.move(to: CGPoint(x: cx, y: 46)); $0.addLine(to: CGPoint(x: cx, y: h-58)) }, with: .color(dark), lineWidth: 1.2)
            ctx.stroke(Path { $0.move(to: CGPoint(x: cx-15, y: 50)); $0.addLine(to: CGPoint(x: cx+15, y: 50)) }, with: .color(dark), lineWidth: 1.2)
            for k in 0..<3 {
                let yy = 64 + CGFloat(k)*11
                ctx.stroke(Path { $0.move(to: CGPoint(x: cx-9, y: yy)); $0.addLine(to: CGPoint(x: cx+9, y: yy)) }, with: .color(dark), lineWidth: 1)
            }
        }
    }
}

// Rising, fading embers — the old self burning away.
struct EmberBurst: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                for i in 0..<16 {
                    let seed = Double(i) * 0.41
                    let prog = (t * 0.85 + seed).truncatingRemainder(dividingBy: 1)
                    let x = w*0.5 + sin((t + seed) * 2.2 + Double(i)) * (6 + Double(i % 5) * 4)
                    let y = h - prog * h
                    let op = (1 - prog) * 0.9
                    let r = 1.4 + (1 - prog) * 2.2
                    let col = i % 3 == 0 ? blendHex(0xFFB24A, 0xFFD27A, 0.3) : Theme.acc
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r*2, height: r*2)), with: .color(col.opacity(op)))
                }
            }
        }
    }
}
