import SwiftUI

// App Store screenshots: a bold caption over a framed iPhone showing a real app screen,
// on the brand background. Rendered full-screen in the sim (STETIC_ASHOT=0…4), grabbed,
// then upscaled to the exact 1242x2688 App Store size. Order mirrors the marketing story.
struct AppStoreShot: View {
    let headline: String
    let sub: String
    let image: String        // bundled app screenshot (real screen)
    var frame: UInt = 0x2A2A2E   // device-edge tint

    static let all: [AppStoreShot] = [
        .init(headline: "Find your\nweak points.",
              sub: "One scan reveals what's holding your physique back.",
              image: "intro_score"),
        .init(headline: "Personalized\nplans.",
              sub: "A plan that targets what's actually lagging.",
              image: "intro_plan"),
        .init(headline: "Aesthetic,\nnot swole.",
              sub: "Built for the lean, movie-star look — not mass.",
              image: "intro_compare", frame: 0xC8FF3D),
        .init(headline: "Hit your macros,\neffortlessly.",
              sub: "Scan any meal. No math, no guessing.",
              image: "intro_meal"),
        .init(headline: "Progress\nevery session.",
              sub: "Log your lifts — we tell you when to go heavier.",
              image: "intro_session_new", frame: 0x8A8A92),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let phoneW = w * 0.70
            ZStack {
                Color(hex: 0x08080A).ignoresSafeArea()
                // lime bloom behind the device
                RadialGradient(colors: [Theme.acc.opacity(0.22), .clear],
                               center: .center, startRadius: 10, endRadius: phoneW * 1.1)
                    .frame(width: phoneW * 2, height: phoneW * 2)
                    .offset(y: geo.size.height * 0.16)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: geo.size.height * 0.085)
                    Text(headline)
                        .font(.system(size: 34, weight: .heavy)).foregroundStyle(Theme.txt)
                        .multilineTextAlignment(.center).lineSpacing(1)
                        .lineLimit(2).minimumScaleFactor(0.7)
                        .frame(width: w - 48)
                    Text(sub)
                        .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.mut)
                        .multilineTextAlignment(.center).lineSpacing(3)
                        .lineLimit(3).minimumScaleFactor(0.8)
                        .frame(width: w - 76)
                        .padding(.top, 14)
                    Spacer().frame(height: geo.size.height * 0.04)
                    phone(width: phoneW)
                    Spacer(minLength: 0)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // A clean iPhone frame: graphite/lime/silver edge, rounded screen, soft lime glow.
    private func phone(width: CGFloat) -> some View {
        let screenR = width * 0.135
        let bezel = width * 0.028
        return Image(uiImage: UIImage(named: image) ?? UIImage())
            .resizable().aspectRatio(contentMode: .fit)
            .frame(width: width)
            .clipShape(RoundedRectangle(cornerRadius: screenR, style: .continuous))
            .padding(bezel)
            .background(
                RoundedRectangle(cornerRadius: screenR + bezel, style: .continuous)
                    .fill(Color(hex: frame))
                    .overlay(RoundedRectangle(cornerRadius: screenR + bezel, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1))
            )
            .shadow(color: Theme.acc.opacity(0.28), radius: 38, y: 12)
            .shadow(color: .black.opacity(0.5), radius: 24, y: 18)
    }
}
