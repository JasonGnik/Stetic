import SwiftUI
import Charts

// Progress + profile: score over time, latest delta, recent sessions, re-scan.
struct ProgressScreen: View {
    let scan: ScoreCard?
    var name: String = ""
    let onNewScan: () -> Void

    @State private var points: [ScanPoint] = []
    @State private var sessions: [WorkoutLog] = []
    @State private var shareURL: URL?
    @State private var weights: [WeightPoint] = []
    @State private var goalKg: Double?
    @State private var showWeightSheet = false
    @State private var showSettings = false
    @State private var entryKg: Double = 80
    @State private var entryUnit = 0   // 0 = lb, 1 = kg

    private func lb(_ kg: Double) -> Int { Int((kg * 2.20462).rounded()) }
    private var currentKg: Double? { weights.last?.weight_kg }

    private var latest: ScanPoint? { points.last }
    private var previous: ScanPoint? { points.count >= 2 ? points[points.count - 2] : nil }
    private var delta: Double? { guard let l = latest, let p = previous else { return nil }; return l.aesthetic_score - p.aesthetic_score }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Progress").font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.txt)
                    Spacer()
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill").font(.system(size: 18)).foregroundStyle(Theme.mut)
                    }
                }
                scoreHeader
                weightCard
                if points.count >= 2 { chartCard } else { needMoreCard }
                HStack(spacing: 10) {
                    rescanButton
                    if let shareURL {
                        ShareLink(item: shareURL, preview: SharePreview("My Stetic rank", image: Image(systemName: "rosette"))) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 16, weight: .bold))
                                .frame(width: 52, height: 50)
                                .background(RoundedRectangle(cornerRadius: 13).fill(Theme.card)
                                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.line, lineWidth: 1)))
                                .foregroundStyle(Theme.acc)
                        }
                    }
                }
                if !sessions.isEmpty { sessionsSection }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
        }
        .background(Theme.bg.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .task {
            points = (try? await ScanAPI.shared.scanPoints()) ?? []
            sessions = (try? await ScanAPI.shared.recentWorkouts()) ?? []
            await loadWeights()
        }
        .sheet(isPresented: $showWeightSheet) { weightSheet }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .task(id: scan?.id) {
            if let scan { shareURL = await MainActor.run { ShareCard.makeImageURL(scan, name: name) } }
        }
    }

    private var scoreHeader: some View {
        let score = latest?.aesthetic_score ?? scan?.aesthetic_score ?? 0
        let tier = Tier.forScore(score)
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.1f", score)).font(.system(size: 34, weight: .heavy)).foregroundStyle(tier.color)
                Text(tier.label).font(.system(size: 12, weight: .bold)).foregroundStyle(tier.color)
            }
            if let d = delta {
                let up = d >= 0
                HStack(spacing: 3) {
                    Image(systemName: up ? "arrow.up.right" : "arrow.down.right").font(.system(size: 11, weight: .bold))
                    Text(String(format: "%+.1f", d)).font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(up ? Theme.acc : Theme.red)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill((up ? Theme.acc : Theme.red).opacity(0.15)))
                Text("since last scan").font(.system(size: 11)).foregroundStyle(Theme.mut)
            }
            Spacer()
            if let bf = latest?.body_fat {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f%%", bf)).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.txt)
                    Text("body fat").font(.system(size: 10)).foregroundStyle(Theme.mut)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AESTHETIC SCORE").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
            Chart {
                ForEach(points) { p in
                    AreaMark(x: .value("Date", p.date), y: .value("Score", p.aesthetic_score))
                        .foregroundStyle(.linearGradient(colors: [Theme.acc.opacity(0.28), Theme.acc.opacity(0.02)],
                                                         startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Date", p.date), y: .value("Score", p.aesthetic_score))
                        .foregroundStyle(Theme.acc).lineStyle(.init(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", p.date), y: .value("Score", p.aesthetic_score))
                        .foregroundStyle(Theme.acc).symbolSize(36)
                }
            }
            .chartYScale(domain: chartLow...10)
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) { v in
                AxisGridLine().foregroundStyle(Theme.line.opacity(0.5))
                AxisValueLabel().foregroundStyle(Theme.mut)
            } }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel(format: .dateTime.month().day()).foregroundStyle(Theme.mut)
            } }
            .frame(height: 180)
            .clipped()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    private var chartLow: Double {
        let mn = points.map { $0.aesthetic_score }.min() ?? 0
        return max(0, (mn - 1).rounded(.down))
    }

    private var needMoreCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 26)).foregroundStyle(Theme.acc)
            Text("Re-scan to see your climb").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
            Text("Your score, rank and weak points — tracked over time.").font(.system(size: 12))
                .foregroundStyle(Theme.mut).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 26)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
    }

    private var rescanButton: some View {
        Button(action: onNewScan) {
            HStack(spacing: 10) {
                Image(systemName: "camera.viewfinder").font(.system(size: 16, weight: .bold))
                Text("New scan").font(.system(size: 15, weight: .bold))
            }
            .frame(maxWidth: .infinity).padding(14)
            .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
            .foregroundStyle(Color(hex: 0x0E0E10))
        }
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT SESSIONS").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
            ForEach(sessions) { s in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(Theme.acc)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.day_label ?? "Session").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                        Text(relativeDay(s.log_date)).font(.system(size: 11)).foregroundStyle(Theme.mut)
                    }
                    Spacer()
                    if let n = s.exercises.first.map({ _ in s.exercises.count }), n > 0 {
                        Text("\(n) exercises").font(.system(size: 11)).foregroundStyle(Theme.mut)
                    }
                }
                .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            }
        }
    }

    private var weightCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("BODYWEIGHT").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
                if let kg = currentKg {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(lb(kg))").font(.system(size: 24, weight: .heavy)).foregroundStyle(Theme.txt)
                        Text("lb").font(.system(size: 13)).foregroundStyle(Theme.mut)
                        if let g = goalKg { Text("· goal \(lb(g)) lb").font(.system(size: 12)).foregroundStyle(Theme.acc) }
                    }
                } else {
                    Text("Log your weight to track it").font(.system(size: 13)).foregroundStyle(Theme.mut)
                }
            }
            Spacer()
            Button {
                entryKg = currentKg ?? goalKg ?? 80
                showWeightSheet = true
            } label: {
                Text("+ Log").font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Capsule().fill(Theme.acc)).foregroundStyle(Color(hex: 0x0E0E10))
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
    }

    private var weightSheet: some View {
        VStack(spacing: 18) {
            Capsule().fill(Theme.line).frame(width: 38, height: 5).padding(.top, 10)
            Text("Log your weight").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
            Text(entryUnit == 0 ? "\(lb(entryKg)) lb" : "\(Int(entryKg)) kg")
                .font(.system(size: 40, weight: .heavy)).foregroundStyle(Theme.txt)
            Slider(value: $entryKg, in: 40...180, step: 1).tint(Theme.acc).padding(.horizontal, 30)
            HStack(spacing: 8) {
                ForEach(["lb", "kg"].indices, id: \.self) { i in
                    Button { entryUnit = i } label: {
                        Text(["lb", "kg"][i]).font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 16).padding(.vertical, 7)
                            .background(Capsule().fill(entryUnit == i ? Theme.acc : Theme.card))
                            .foregroundStyle(entryUnit == i ? Color(hex: 0x0E0E10) : Theme.mut)
                    }.buttonStyle(.plain)
                }
            }
            Button {
                Task {
                    try? await ScanAPI.shared.logWeight(entryKg)
                    await HealthKitManager.shared.saveWeight(kg: entryKg)
                    showWeightSheet = false; await loadWeights()
                }
            } label: {
                Text("Save").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.acc)).foregroundStyle(Color(hex: 0x0E0E10))
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.height(330)])
    }

    private func loadWeights() async {
        weights = (try? await ScanAPI.shared.weightPoints()) ?? []
        let t = (try? await ScanAPI.shared.weightTargets()) ?? (current: nil, goal: nil)
        goalKg = t.goal
        if currentKg == nil, let c = t.current { entryKg = c }
    }

    private func relativeDay(_ s: String?) -> String {
        guard let s, let d = LogDate.fmt.date(from: s) else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: d)
    }
}
