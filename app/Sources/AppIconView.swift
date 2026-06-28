import SwiftUI

// A custom-drawn crown app icon — lime on near-black. Hand-built (not an SF Symbol,
// no third-party render) so it's clean for App Store use with no watermark or license issue.
// Rendered via STETIC_APPICON=1, screenshot, center-cropped to a 1024 square.
struct AppIconView: View {
    var body: some View {
        ZStack {
            Color(hex: 0x0A0A0C).ignoresSafeArea()
            GeometryReader { geo in
                let s = geo.size.width * 0.62          // crown box size
                Crown()
                    .fill(Theme.acc)
                    .frame(width: s, height: s * 0.82)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }
}

// Three-peak crown with rounded points and a banded base, drawn as one filled shape
// plus circular finials. Proportions tuned to read well at small icon sizes.
struct Crown: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * w, y: r.minY + y * h) }
        let ball = w * 0.085                          // finial radius

        var p = Path()
        // Crown body: bottom band → up the sides → zig-zag across the peaks.
        p.move(to: pt(0.06, 0.66))                    // bottom-left of band
        p.addLine(to: pt(0.06, 0.40))                 // up to left peak base
        p.addLine(to: pt(0.30, 0.52))                 // dip to left valley
        p.addLine(to: pt(0.50, 0.30))                 // up to center peak
        p.addLine(to: pt(0.70, 0.52))                 // dip to right valley
        p.addLine(to: pt(0.94, 0.40))                 // up to right peak base
        p.addLine(to: pt(0.94, 0.66))                 // down to bottom-right of band
        p.closeSubpath()

        // Base band (solid block below the body for a grounded crown).
        p.addRoundedRect(in: CGRect(x: pt(0.06, 0.72).x, y: pt(0, 0.72).y,
                                    width: w * 0.88, height: h * 0.20),
                         cornerSize: CGSize(width: w * 0.05, height: w * 0.05))

        // Finials (balls) on the three peaks.
        for (cx, cy) in [(0.06, 0.40), (0.50, 0.30), (0.94, 0.40)] {
            let c = pt(CGFloat(cx), CGFloat(cy))
            p.addEllipse(in: CGRect(x: c.x - ball, y: c.y - ball, width: ball * 2, height: ball * 2))
        }
        return p
    }
}
