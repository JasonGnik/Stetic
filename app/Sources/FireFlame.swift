import SwiftUI

// A live, fire-colored flame that flickers (gold → orange → red) and can "flare up"
// for a celebration. Used on the streak card and the finish-session overlay.
struct FireFlame: View {
    var size: CGFloat = 28
    var flare: Bool = false          // bigger, brighter burst (e.g. just logged a session)

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let flick = sin(t * 7) * 0.5 + 0.5            // 0…1 base flicker
            let flick2 = sin(t * 13 + 1) * 0.5 + 0.5      // faster secondary flicker
            let intensity = flare ? 1.0 : 0.55
            Image(systemName: "flame.fill")
                .font(.system(size: size))
                .foregroundStyle(
                    LinearGradient(colors: [Color(hex: 0xFFD23F), Color(hex: 0xFF7A1A), Color(hex: 0xFF3B2F)],
                                   startPoint: .bottom, endPoint: .top))
                .scaleEffect(x: 1 + flick * 0.04 * intensity,
                             y: 1 + (flick * 0.10 + flick2 * 0.05) * intensity,
                             anchor: .bottom)
                .shadow(color: Color(hex: 0xFF7A1A).opacity((0.35 + flick * 0.35) * intensity),
                        radius: flare ? 16 : 8)
        }
    }
}
