import SwiftUI

// A branded, story-shaped card the user shares to socials — the viral loop.
struct ShareCardView: View {
    let card: ScoreCard
    var name: String = ""

    var body: some View {
        let tier = Tier.forScore(card.aesthetic_score)
        VStack(spacing: 0) {
            Text("STETIC").font(.system(size: 22, weight: .heavy)).tracking(4).foregroundStyle(Theme.acc)
                .padding(.top, 34)
            Spacer()
            ZStack {
                Circle().fill(tier.color.opacity(0.14)).frame(width: 132, height: 132)
                Circle().stroke(tier.color, lineWidth: 2).frame(width: 132, height: 132)
                Image(systemName: tier.icon).font(.system(size: 58, weight: .semibold)).foregroundStyle(tier.color)
            }
            Text(tier.label.uppercased()).font(.system(size: 17, weight: .heavy)).tracking(2)
                .foregroundStyle(tier.color).padding(.top, 16)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", card.aesthetic_score)).font(.system(size: 84, weight: .heavy)).foregroundStyle(Theme.txt)
                Text("/10").font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.mut)
            }
            .padding(.top, 6)
            Text(name.isEmpty ? "Stetic Score" : "\(name)'s Stetic Score")
                .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.mut)
            HStack(spacing: 22) {
                stat(String(format: "%.0f%%", card.body_fat), "Body fat")
                stat(String(format: "%.1f", card.potential), "Potential")
            }
            .padding(.top, 22)
            Spacer()
            VStack(spacing: 3) {
                Text("What's your score?").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                Text("Scan your physique on Stetic").font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            .padding(.bottom, 34)
        }
        .frame(width: 340, height: 600)
        .background(
            ZStack {
                Theme.bg
                Circle().fill(tier.color.opacity(0.10)).frame(width: 360).blur(radius: 70).offset(y: -150)
            }
        )
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.txt)
            Text(l).font(.system(size: 11)).foregroundStyle(Theme.mut)
        }
    }
}

enum ShareCard {
    // Render the card to a PNG file URL for the share sheet.
    @MainActor static func makeImageURL(_ card: ScoreCard, name: String) -> URL? {
        let renderer = ImageRenderer(content: ShareCardView(card: card, name: name).preferredColorScheme(.dark))
        renderer.scale = 3
        guard let img = renderer.uiImage, let data = img.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("stetic-rank.png")
        do { try data.write(to: url); return url } catch { return nil }
    }
}
