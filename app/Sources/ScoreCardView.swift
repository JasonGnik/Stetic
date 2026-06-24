import SwiftUI

struct ScoreCardView: View {
    let card: ScoreCard
    var onGetPlan: () -> Void = {}
    var onScanAnother: (() -> Void)? = nil
    @State private var showEstInfo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                hero
                verdict
                stats
                potentialCallout
                musclesSection
                climbSection
                cta
                if let onScanAnother {
                    Button("Scan another", action: onScanAnother)
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.mut)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .alert("Estimated rating", isPresented: $showEstInfo) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("This muscle wasn't clearly visible in your photo, so Stetic estimated it from your overall physique. Add a side or back photo for an exact read.")
        }
    }

    // MARK: header
    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Circle().fill(Theme.acc).frame(width: 9, height: 9)
                Text("Stetic").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.acc)
            }
            Spacer()
            Text("YOUR ANALYSIS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.mut)
        }
        .foregroundStyle(Theme.txt)
    }

    // MARK: hero
    private var hero: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 14)
                .fill(card.tier.color.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(card.tier.color, lineWidth: 2))
                .frame(width: 62, height: 62)
                .overlay(
                    Image(systemName: card.tier.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(card.tier.color)
                )
            Text(card.tier.label)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(card.tier.color)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", card.aesthetic_score))
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(Theme.txt)
                Text("/10 aesthetic")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.mut)
            }
        }
        .padding(.top, 2)
    }

    // MARK: verdict
    private var verdict: some View {
        Text(card.verdict)
            .font(.system(size: 12.5))
            .foregroundStyle(Color(hex: 0xD2D2D8))
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0x1A1A1E)))
    }

    // MARK: stats
    private var stats: some View {
        HStack(spacing: 7) {
            statTile("Body fat", String(format: "%.0f%%", card.body_fat), Theme.txt)
            if let flag = card.size_flag {
                statTile("Size", flag.capitalized, Theme.red)
            } else {
                statTile("Symmetry", String(format: "%.1f", card.symmetry), Theme.txt)
            }
        }
    }

    // Potential = the tier this physique can reach. Color-coded by that tier.
    private var potentialCallout: some View {
        let tier = Tier.forScore(card.potential)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR POTENTIAL").font(.system(size: 10.5, weight: .semibold)).tracking(0.8).foregroundStyle(Theme.mut)
                Text("\(card.potentialTimeframe) of focused training").font(.system(size: 11)).foregroundStyle(Theme.mut)
            }
            Spacer()
            HStack(spacing: 6) {
                Text(String(format: "%.1f", card.potential)).font(.system(size: 22, weight: .heavy)).foregroundStyle(tier.color)
                Text(tier.label).font(.system(size: 13, weight: .bold)).foregroundStyle(tier.color)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(tier.color.opacity(0.3), lineWidth: 1))
        )
    }

    private func statTile(_ k: String, _ v: String, _ vColor: Color) -> some View {
        VStack(spacing: 1) {
            Text(k).font(.system(size: 10)).foregroundStyle(Theme.mut)
            Text(v).font(.system(size: 16, weight: .bold)).foregroundStyle(vColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color(hex: 0x1A1A1E)))
    }

    // MARK: muscles
    private var musclesSection: some View {
        let ranked = card.rankedMuscles
        return VStack(alignment: .leading, spacing: 8) {
            Text("MUSCLE GROUPS · RANKED")
                .font(.system(size: 10.5, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Theme.mut)
            VStack(spacing: 7) {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { idx, m in
                    muscleRow(m, isTop: idx == 0, isBottom: idx == ranked.count - 1)
                }
            }
        }
    }

    private func muscleRow(_ m: ScoreCard.Muscle, isTop: Bool, isBottom: Bool) -> some View {
        let color = isTop ? Theme.acc : (isBottom ? Theme.red : ScoreCard.muscleColor(m.score))
        let highlight: Color? = isTop ? Color(hex: 0x16210C) : (isBottom ? Color(hex: 0x21100F) : nil)
        let border: Color? = isTop ? Color(hex: 0x2C3A10) : (isBottom ? Color(hex: 0x3A1614) : nil)
        return VStack(spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    if isTop { Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold)) }
                    if isBottom { Image(systemName: "arrow.down.right").font(.system(size: 11, weight: .bold)) }
                    Text(m.group.capitalized).font(.system(size: 12, weight: isTop || isBottom ? .semibold : .regular))
                    if isTop { Text("· strongest").font(.system(size: 12)).foregroundStyle(Theme.mut) }
                    if isBottom { Text("· weakest").font(.system(size: 12)).foregroundStyle(Theme.mut) }
                    if !m.visible {
                        Button { showEstInfo = true } label: {
                            HStack(spacing: 2) {
                                Text("est").font(.system(size: 9, weight: .semibold))
                                Image(systemName: "info.circle").font(.system(size: 8))
                            }
                            .foregroundStyle(Theme.mut)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(Theme.line))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .foregroundStyle(isTop ? Theme.acc : (isBottom ? Theme.red : Theme.txt))
                Spacer()
                Text(String(format: "%.1f", m.score))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line).frame(height: 5)
                    Capsule().fill(color).frame(width: geo.size.width * (m.score / 10), height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(highlight != nil ? 8 : 0)
        .background(
            Group {
                if let highlight, let border {
                    RoundedRectangle(cornerRadius: 8).fill(highlight)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))
                }
            }
        )
    }

    // MARK: climb strip + next
    private var climbSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                ForEach(Array(Tier.allCases.enumerated()), id: \.element) { idx, t in
                    Capsule()
                        .fill(idx <= card.tierIndex ? t.color : Theme.line)
                        .frame(height: 5)
                }
            }
            Group {
                if let (next, delta) = card.nextTier {
                    HStack(spacing: 3) {
                        Text("Next:").foregroundStyle(Theme.mut)
                        Text(next.label).foregroundStyle(next.color)
                        Text(String(format: "+%.1f", delta)).foregroundStyle(Theme.mut)
                    }
                } else {
                    HStack(spacing: 3) {
                        Text("Apex tier reached —").foregroundStyle(Theme.mut)
                        Text(card.tier.label).foregroundStyle(card.tier.color)
                    }
                }
            }
            .font(.system(size: 10.5))
        }
    }

    // MARK: cta
    private var cta: some View {
        Button(action: onGetPlan) {
            VStack(spacing: 2) {
                Text("Get my full plan").font(.system(size: 14.5, weight: .bold))
                Text("Training · nutrition · full breakdown")
                    .font(.system(size: 10.5, weight: .semibold)).opacity(0.68)
            }
            .frame(maxWidth: .infinity)
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 11).fill(Theme.acc))
            .foregroundStyle(Color(hex: 0x0E0E10))
        }
        .padding(.top, 2)
    }
}

#Preview {
    ScoreCardView(card: .sample).preferredColorScheme(.dark)
}
