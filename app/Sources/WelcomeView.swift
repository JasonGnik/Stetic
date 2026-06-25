import SwiftUI

// The very first screen — congratulate + reaffirm the decision before the cinematic intro.
// Gender-neutral (sex isn't asked until onboarding).
struct WelcomeView: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 18) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 50, weight: .semibold)).foregroundStyle(Theme.acc)
                    Text("WELCOME TO STETIC")
                        .font(.system(size: 11, weight: .bold)).tracking(2).foregroundStyle(Theme.mut)
                    Text("You're already ahead.")
                        .font(.system(size: 28, weight: .heavy)).multilineTextAlignment(.center).foregroundStyle(Theme.txt)
                    Text("Most people guess in the gym for years. In the next two minutes you'll see your real starting point — and exactly how far you can go.")
                        .font(.system(size: 15)).multilineTextAlignment(.center).lineSpacing(4)
                        .foregroundStyle(Theme.mut).padding(.horizontal, 30)
                }
                Spacer()
                Button { onContinue() } label: {
                    Text("Let's go").font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(15)
                        .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
                        .foregroundStyle(Color(hex: 0x0E0E10))
                }
                .padding(.horizontal, 22).padding(.bottom, 14)
            }
        }
    }
}

#Preview { WelcomeView(onContinue: {}).preferredColorScheme(.dark) }
