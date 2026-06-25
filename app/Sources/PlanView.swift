import SwiftUI

struct PlanView: View {
    var showsClose: Bool = true
    var onStart: (() -> Void)? = nil
    var onRescan: (() -> Void)? = nil      // present the physique re-scan flow (main app only)
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .loading
    @State private var bundle: ScanAPI.PlanBundle?
    @State private var confirm: PlanAction?

    enum Phase: Equatable { case loading, ready, error(String) }

    enum PlanAction: Identifiable {
        case newPlan, finish, archive, delete
        var id: Int { hashValue }
        var title: String {
            switch self {
            case .newPlan: return "Generate a new plan?"
            case .finish:  return "Finish this block?"
            case .archive: return "Archive this plan?"
            case .delete:  return "Delete this plan?"
            }
        }
        var message: String {
            switch self {
            case .newPlan: return "We'll build a fresh plan from your latest scan. Your current plan is archived."
            case .finish:  return "Marks this block done and builds your next one from your latest scan. Re-scan first for the most accurate progression."
            case .archive: return "Moves this plan to your history and starts a fresh one."
            case .delete:  return "Permanently removes this plan. This can't be undone."
            }
        }
        var button: String {
            switch self {
            case .newPlan: return "New plan"; case .finish: return "Finish & rebuild"
            case .archive: return "Archive"; case .delete: return "Delete"
            }
        }
        var destructive: Bool { self == .delete }
    }

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
        .confirmationDialog(confirm?.title ?? "", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }), titleVisibility: .visible, presenting: confirm) { action in
            Button(action.button, role: action.destructive ? .destructive : nil) { perform(action) }
            Button("Cancel", role: .cancel) {}
        } message: { action in Text(action.message) }
    }

    private func load() async {
        do { bundle = try await ScanAPI.shared.plan(); phase = .ready }
        catch { phase = .error(error.localizedDescription) }
    }

    // Weeks elapsed in the current block (1-based), capped at the block length.
    private var weekInfo: (current: Int, total: Int)? {
        guard let started = bundle?.startedAt else { return nil }
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: started) ?? { let b = ISO8601DateFormatter(); b.formatOptions = [.withInternetDateTime]; return b.date(from: started) }()
        guard let date else { return nil }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return (min(8, days / 7 + 1), 8)
    }

    private func perform(_ action: PlanAction) {
        let id = bundle?.id
        Task {
            switch action {
            case .delete:
                if let id { try? await ScanAPI.shared.deletePlan(id) }
                await reload()
            case .archive:
                if let id { try? await ScanAPI.shared.setPlanStatus(id, "archived") }
                await reload()
            case .newPlan, .finish:
                if action == .finish, let id { try? await ScanAPI.shared.setPlanStatus(id, "finished") }
                await MainActor.run { phase = .loading }
                let fresh = try? await ScanAPI.shared.regeneratePlan(archiving: action == .newPlan ? id : nil)
                await MainActor.run {
                    if let fresh { bundle = fresh; phase = .ready } else { Task { await reload() } }
                }
            }
        }
    }

    private func reload() async {
        await MainActor.run { phase = .loading }
        ScanAPI.shared.clearPlanCache()
        do { bundle = try await ScanAPI.shared.plan(); await MainActor.run { phase = .ready } }
        catch { await MainActor.run { phase = .error(error.localizedDescription) } }
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
                        HStack(spacing: 6) {
                            Text(p.goal_label.uppercased())
                                .font(.system(size: 10.5, weight: .bold)).tracking(0.6)
                                .foregroundStyle(Color(hex: 0x0E0E10))
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .background(Capsule().fill(Theme.acc))
                            if let wk = weekInfo {
                                Text("WEEK \(wk.current) OF \(wk.total)")
                                    .font(.system(size: 10.5, weight: .bold)).tracking(0.4)
                                    .foregroundStyle(Theme.mut)
                                    .padding(.horizontal, 9).padding(.vertical, 4)
                                    .background(Capsule().fill(Theme.card).overlay(Capsule().stroke(Theme.line, lineWidth: 1)))
                            }
                        }
                    }
                    Spacer()
                    if onRescan != nil { planMenu }
                    if showsClose {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                                .padding(8).background(Circle().fill(Theme.card))
                        }
                    }
                }
                Text(p.summary).font(.system(size: 13.5)).foregroundStyle(Color(hex: 0xD2D2D8)).lineSpacing(4)

                includedHeader
                projectionHero(p.projection, scan: scan)
                if (p.split_critique?.isEmpty == false) || (p.split_changes?.isEmpty == false) {
                    section("YOUR CURRENT SPLIT") { critique(p.split_critique, changes: p.split_changes) }
                }
                macros(p.macros)
                section("PRIORITIES") { priorities(p.priorities) }
                section("WEEKLY SPLIT") { split(p.weekly_split, weak: weakGroups(p.muscle_breakdown)) }
                section("MUSCLE BREAKDOWN") { breakdown(p.muscle_breakdown, weak: weakGroups(p.muscle_breakdown)) }
                if let onStart {
                    Button { onStart() } label: {
                        Text("Start training →").font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity).padding(15)
                            .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
                            .foregroundStyle(Color(hex: 0x0E0E10))
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
    }

    private var planMenu: some View {
        Menu {
            if let onRescan {
                Button { onRescan() } label: { Label("Re-scan my physique", systemImage: "camera.viewfinder") }
            }
            Button { confirm = .newPlan } label: { Label("Generate a new plan", systemImage: "sparkles") }
            Button { confirm = .finish } label: { Label("Finish this block", systemImage: "flag.checkered") }
            Divider()
            Button { confirm = .archive } label: { Label("Archive plan", systemImage: "archivebox") }
            Button(role: .destructive) { confirm = .delete } label: { Label("Delete plan", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                .frame(width: 34, height: 34).background(Circle().fill(Theme.card))
        }
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
                            // cumulative gain from the starting score (not the previous milestone)
                            Text(String(format: "+%.1f", max(0, m.projected_score - scan.aesthetic_score)))
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

    private func critique(_ headline: String?, changes: [PlanContent.SplitChange]?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let headline, !headline.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 13)).foregroundStyle(Theme.amber).padding(.top, 1)
                    Text(headline).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: 0xE6E0CF)).lineSpacing(3)
                }
            }
            if let changes, !changes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(changes) { c in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.acc).padding(.top, 3)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.change).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt)
                                Text(c.why).font(.system(size: 11.5)).foregroundStyle(Theme.mut).lineSpacing(2)
                            }
                        }
                    }
                }
            }
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

    private func split(_ days: [PlanContent.Day], weak: Set<String>) -> some View {
        VStack(spacing: 10) {
            ForEach(days) { d in
                VStack(alignment: .leading, spacing: 10) {
                    Text(d.day).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.acc)
                    ForEach(d.exercises) { e in
                        let hitsWeak = weak.contains { e.target.lowercased().contains($0) }
                        HStack(spacing: 10) {
                            Circle().fill(hitsWeak ? Theme.red : Theme.acc).frame(width: 6, height: 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                                HStack(spacing: 5) {
                                    Text(e.target).font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(hitsWeak ? Theme.red.opacity(0.18) : Theme.line))
                                        .foregroundStyle(hitsWeak ? Theme.red : Theme.mut)
                                    if hitsWeak {
                                        Text("weak point").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.red)
                                    }
                                }
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

    private func breakdown(_ groups: [PlanContent.Breakdown], weak: Set<String>) -> some View {
        VStack(spacing: 10) {
            ForEach(groups.sorted { $0.rating > $1.rating }) { g in
                let isWeak = weak.contains(g.group.lowercased())
                HStack(alignment: .top, spacing: 12) {
                    BodyMap(group: g.group, tint: isWeak ? Theme.red : Theme.acc)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(g.group.capitalized).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                            if isWeak {
                                Text("WEAK POINT").font(.system(size: 8.5, weight: .bold))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Capsule().fill(Theme.red.opacity(0.18))).foregroundStyle(Theme.red)
                            }
                            Spacer()
                            Text(String(format: "%.1f", g.rating)).font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(ScoreCard.muscleColor(g.rating))
                        }
                        Text(g.detail).font(.system(size: 12.5)).foregroundStyle(Color(hex: 0xC9C9CF)).lineSpacing(3)
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(g.sub) { s in subRow(s) }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14).fill(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isWeak ? Theme.red.opacity(0.3) : Theme.line, lineWidth: 1))
                )
            }
        }
    }

    // What the plan includes — quick visual scannable header.
    private var includedHeader: some View {
        HStack(spacing: 8) {
            includedChip("dumbbell.fill", "Training")
            includedChip("fork.knife", "Nutrition")
            includedChip("scope", "Weak points")
            includedChip("chart.line.uptrend.xyaxis", "Progress")
        }
    }
    private func includedChip(_ icon: String, _ label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Theme.acc)
            Text(label).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(Theme.mut)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
    }

    // A single sub-muscle row: status-colored name + label, then the training cue.
    private func subRow(_ s: PlanContent.Breakdown.Sub) -> some View {
        let c = subColor(s.status)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 7) {
                Circle().fill(c).frame(width: 5, height: 5)
                Text(s.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt)
                Text(s.status).font(.system(size: 9.5, weight: .bold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(c.opacity(0.16))).foregroundStyle(c)
                Spacer(minLength: 0)
            }
            Text(s.cue).font(.system(size: 11)).foregroundStyle(Theme.mut).lineSpacing(2)
                .padding(.leading, 12)
        }
    }

    // Lagging/needs-work statuses read red; everything else reads lime.
    private func subColor(_ status: String) -> Color {
        let s = status.lowercased()
        let weak = ["lag", "weak", "lack", "need", "under", "thin", "behind", "poor", "small"]
        return weak.contains { s.contains($0) } ? Theme.red : Theme.acc
    }

    private func weakGroups(_ groups: [PlanContent.Breakdown]) -> Set<String> {
        Set(groups.sorted { $0.rating < $1.rating }.prefix(2).map { $0.group.lowercased() })
    }
}
