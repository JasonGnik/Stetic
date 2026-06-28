import SwiftUI

// The Greek God rank crown as an app icon: the real crown.fill mark, lime on near-black.
struct AppIconView: View {
    var body: some View {
        ZStack {
            Color(hex: 0x0A0A0C)
            Image(systemName: "crown.fill")
                .font(.system(size: 240, weight: .bold))
                .foregroundStyle(Theme.acc)
        }
        .ignoresSafeArea()
    }
}
