import SwiftUI

// Animated "scientific scanner" loader — rotating reticle arcs, pulsing core,
// sweeping scan line, and cycling status text. Used for AI calls (scan, plan).
struct ScanningLoader: View {
    var title: String = "Analyzing"
    var messages: [String]
    @State private var msgIndex = 0
    @State private var start = Date()

    var body: some View {
        VStack(spacing: 30) {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSince(start)
                ZStack {
                    Reticle()
                        .stroke(Theme.line, lineWidth: 1)
                        .opacity(0.45)

                    // counter-rotating arcs
                    ForEach(0..<3, id: \.self) { i in
                        let dir: Double = i % 2 == 0 ? 1 : -1
                        Arc(sweep: .degrees(70 + Double(i) * 35))
                            .stroke(Theme.acc.opacity(0.85 - Double(i) * 0.22),
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(width: 150 - CGFloat(i) * 34, height: 150 - CGFloat(i) * 34)
                            .rotationEffect(.degrees(t * (55 + Double(i) * 45) * dir))
                    }

                    // sweeping horizontal scan line
                    let scanY = sin(t * 1.5) * 78
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, Theme.acc.opacity(0.6), .clear],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: 170, height: 2)
                        .offset(y: scanY)
                        .blur(radius: 0.5)

                    // pulsing core
                    let pulse = (sin(t * 2.2) + 1) / 2
                    Circle()
                        .fill(Theme.acc)
                        .frame(width: 12, height: 12)
                        .scaleEffect(0.7 + pulse * 0.7)
                        .shadow(color: Theme.acc.opacity(0.9), radius: 8 + pulse * 10)
                }
                .frame(width: 190, height: 190)
            }

            VStack(spacing: 12) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold)).tracking(2)
                    .foregroundStyle(Theme.mut)
                Text(messages[min(msgIndex, messages.count - 1)])
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .id(msgIndex)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                HStack(spacing: 6) {
                    ForEach(messages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i <= msgIndex ? Theme.acc : Theme.line)
                            .frame(width: i == msgIndex ? 18 : 6, height: 4)
                            .animation(.spring(response: 0.4), value: msgIndex)
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { start = Date(); cycle() }
    }

    private func cycle() {
        guard msgIndex < messages.count - 1 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeInOut(duration: 0.4)) { msgIndex += 1 }
            cycle()
        }
    }
}

private struct Arc: Shape {
    var sweep: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: rect.width / 2,
                 startAngle: .degrees(-90), endAngle: .degrees(-90) + sweep,
                 clockwise: false)
        return p
    }
}

private struct Reticle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var r = 24.0
        while r <= rect.width / 2 {
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            r += 30
        }
        p.move(to: CGPoint(x: rect.minX, y: c.y)); p.addLine(to: CGPoint(x: rect.maxX, y: c.y))
        p.move(to: CGPoint(x: c.x, y: rect.minY)); p.addLine(to: CGPoint(x: c.x, y: rect.maxY))
        return p
    }
}

#Preview {
    ScanningLoader(title: "Building your plan",
                   messages: ["Mapping your physique", "Analyzing proportions",
                              "Calibrating ratios", "Targeting weak points", "Finalizing plan"])
        .preferredColorScheme(.dark)
}
