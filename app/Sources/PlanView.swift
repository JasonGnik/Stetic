import SwiftUI

struct PlanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .loading
    @State private var bundle: ScanAPI.PlanBundle?

    enum Phase: Equatable { case loading, ready, error(String) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            switch phase {
            case .loading: loading
            case .error(let m): errorView(m)
            case .ready: if let bundle { content(bundle.content, scan: bundle.scan) }
            }
        }
        .task { await load() }
    }

    private func load() async {
        do { bundle = try await ScanAPI.shared.plan(); phase = .ready }
        catch { phase = .error(error.localizedDescription) }
    }

    // MARK: states
    private var loading: some View {
        ScanningLoader(
            title: "Building your plan",
            messages: ["Reading your physique", "Targeting weak points",
                       "Programming your split", "Calculating macros", "Projecting your results"],
            icons: ["figure.arms.open", "scope", "dumbbell.fill", "fork.knife", "chart.line.uptrend.xyaxis"]
        )
    }
    private func errorView(_ m: String) -> some View {
        VStack(spacing: 12) {
            Text("Couldn't build the plan").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
            Text(m).font(.system(size: 12)).foregroundStyle(Theme.mut).multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Close") { dismiss() }.foregroundStyle(Theme.acc).padding(.top, 4)
        }
    }

    // MARK: content
    private func content(_ p: PlanContent, scan: ScoreCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your Plan").font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.txt)
                        Text(p.goal_label.uppercased())
                            .font(.system(size: 10.5, weight: .bold)).tracking(0.6)
                            .foregroundStyle(Color(hex: 0x0E0E10))
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Capsule().fill(Theme.acc))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                            .padding(8).background(Circle().fill(Theme.card))
                    }
                }
                Text(p.summary).font(.system(size: 13.5)).foregroundStyle(Color(hex: 0xD2D2D8)).lineSpacing(4)

                projectionHero(p.projection, scan: scan)
                if let crit = p.split_critique, !crit.isEmpty {
                    section("YOUR CURRENT SPLIT") { critique(crit) }
                }
                macros(p.macros)
                section("PRIORITIES") { priorities(p.priorities) }
                section("WEEKLY SPLIT") { split(p.weekly_split) }
                section("MUSCLE BREAKDOWN") { breakdown(p.muscle_breakdown) }
            }
            .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: projection — current starting point → "where you can get to" (the game)
    private func projectionHero(_ proj: PlanContent.Projection, scan: ScoreCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── current starting point ──
            Text("STARTING POINT").font(.system(size: 11, weight: .semibold)).tracking(1).foregroundStyle(Theme.mut)
            HStack(spacing: 0) {
                startStat(String(format: "%.1f", scan.aesthetic_score), scan.tier.label, scan.tier.color)
                Divider().frame(height: 34).overlay(Theme.line)
                startStat(String(format: "%.0f%%", scan.body_fat), "Body fat", Theme.txt)
                Divider().frame(height: 34).overlay(Theme.line)
                startStat(String(format: "%.1f", scan.potential), "Potential", Tier.forScore(scan.potential).color)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))

            // ── where you can get to ──
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.acc)
                Text("WHERE YOU CAN GET TO").font(.system(size: 11, weight: .semibold)).tracking(1).foregroundStyle(Theme.mut)
            }
            .padding(.top, 2)
            HStack(spacing: 10) {
                ForEach(proj.milestones) { m in
                    let tier = Tier.forScore(m.projected_score)  // derive — model's tier label is unreliable
                    VStack(alignment: .leading, spacing: 7) {
                        Text("\(m.weeks) WEEKS").font(.system(size: 10, weight: .bold)).tracking(0.5).foregroundStyle(Theme.mut)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", m.projected_score))
                                .font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.txt)
                            Text(String(format: "+%.1f", m.points_gain))
                                .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.acc)
                        }
                        Text(tier.label).font(.system(size: 12, weight: .bold)).foregroundStyle(tier.color)
                        if let bf = m.projected_body_fat {
                            Text(String(format: "%.0f%% body fat", bf)).font(.system(size: 10)).foregroundStyle(Theme.mut)
                        }
                        Divider().overlay(Theme.line)
                        ForEach(m.muscle_gains) { g in
                            HStack(spacing: 4) {
                                Text(g.group.capitalized).font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                                Spacer()
                                Text(String(format: "%.1f", g.from)).font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                                Image(systemName: "arrow.right").font(.system(size: 7, weight: .bold)).foregroundStyle(Theme.mut)
                                Text(String(format: "%.1f", g.to)).font(.system(size: 10.5, weight: .bold)).foregroundStyle(Theme.acc)
                            }
                        }
                        Text(m.summary).font(.system(size: 10.5)).foregroundStyle(Theme.mut).lineSpacing(2).padding(.top, 2)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14).fill(Theme.card)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.acc.opacity(0.25), lineWidth: 1))
                    )
                }
            }
        }
    }

    private func startStat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .heavy)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.mut)
        }
        .frame(maxWidth: .infinity)
    }

    private func critique(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 13)).foregroundStyle(Theme.amber).padding(.top, 1)
            Text(text).font(.system(size: 12.5)).foregroundStyle(Color(hex: 0xD2D2D8)).lineSpacing(3)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0x1E1A12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.amber.opacity(0.25), lineWidth: 1)))
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 11, weight: .semibold)).tracking(1).foregroundStyle(Theme.mut)
            c()
        }
    }

    private func macros(_ m: PlanContent.Macros) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                macroTile("Calories", "\(Int(m.calories))", Theme.txt)
                macroTile("Protein", "\(Int(m.protein_g))g", Theme.acc)
                macroTile("Carbs", "\(Int(m.carbs_g))g", Theme.txt)
                macroTile("Fat", "\(Int(m.fat_g))g", Theme.txt)
            }
            Text(m.rationale).font(.system(size: 11.5)).foregroundStyle(Theme.mut).lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func macroTile(_ k: String, _ v: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 18, weight: .bold)).foregroundStyle(c)
            Text(k).font(.system(size: 10)).foregroundStyle(Theme.mut)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
    }

    private func priorities(_ items: [PlanContent.Priority]) -> some View {
        VStack(spacing: 8) {
            ForEach(items) { p in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(Theme.acc).frame(width: 6, height: 6).padding(.top, 5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.area).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                        Text(p.action).font(.system(size: 12)).foregroundStyle(Theme.mut).lineSpacing(2)
                    }
                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            }
        }
    }

    private func split(_ days: [PlanContent.Day]) -> some View {
        VStack(spacing: 10) {
            ForEach(days) { d in
                VStack(alignment: .leading, spacing: 8) {
                    Text(d.day).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.acc)
                    ForEach(d.exercises) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.txt)
                                Text(e.target).font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                            }
                            Spacer()
                            Text("\(e.sets) × \(e.reps)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            }
        }
    }

    private func breakdown(_ groups: [PlanContent.Breakdown]) -> some View {
        VStack(spacing: 10) {
            ForEach(groups.sorted { $0.rating > $1.rating }) { g in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(g.group.capitalized).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                        Spacer()
                        Text(String(format: "%.1f", g.rating))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ScoreCard.muscleColor(g.rating))
                    }
                    Text(g.detail).font(.system(size: 12)).foregroundStyle(Theme.mut).lineSpacing(2)
                    ForEach(g.sub) { s in
                        HStack(alignment: .top, spacing: 6) {
                            Text(s.name).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Color(hex: 0xD2D2D8))
                            Text("· \(s.cue)").font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                            Spacer()
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            }
        }
    }
}
