import SwiftUI

// Draft App Store screenshots: a bold caption over a real app screen, brand background.
// Order mirrors the onboarding story (scan → plan → log → nutrition → climb).
struct AppStoreShot: View {
    let eyebrow: String
    let caption: String
    let image: String   // bundled screenshot

    static let all: [AppStoreShot] = [
        .init(eyebrow: "SCAN", caption: "Find the\nweak link.", image: "intro_score"),
        .init(eyebrow: "YOUR PLAN", caption: "Built around\nyour weak points.", image: "intro_plan"),
        .init(eyebrow: "TRAIN", caption: "Beat every\nsession.", image: "intro_session"),
        .init(eyebrow: "NUTRITION", caption: "Hit your macros,\neffortlessly.", image: "intro_meal"),
        .init(eyebrow: "ASCEND", caption: "Climb to your\ndream physique.", image: "intro_greekgod"),
    ]

    var body: some View {
        ZStack {
            Color(hex: 0x08080A).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 64)
                VStack(spacing: 12) {
                    Text(eyebrow).font(.system(size: 15, weight: .bold)).tracking(3).foregroundStyle(Theme.acc)
                    Text(caption).font(.system(size: 42, weight: .heavy)).multilineTextAlignment(.center)
                        .lineSpacing(2).foregroundStyle(Theme.txt)
                }
                .padding(.horizontal, 34)
                Spacer().frame(height: 38)
                Image(uiImage: UIImage(named: image) ?? UIImage())
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(Theme.line, lineWidth: 1.5))
                    .shadow(color: Theme.acc.opacity(0.18), radius: 40, y: 10)
                    .padding(.horizontal, 46)
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}
