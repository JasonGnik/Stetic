import SwiftUI

// Log a training session: tick off sets, enter weight × reps, finish to bank the streak.
// Progressive overload is the spine — every exercise shows its rep-range target and last
// session's numbers, beating a set flashes green, and hitting the top of the range tells
// you you're adding weight next time.
struct SessionLogView: View {
    let day: PlanContent.Day
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var exercises: [LoggedExercise]
    @State private var saving = false
    @State private var lastByExercise: [String: [LoggedSet]] = [:]   // beat-the-logbook reference
    @State private var pulsedSets: Set<UUID> = []                    // sets that just beat last (green flash)
    @State private var flash: String?                               // transient top-of-range banner
    @State private var progressions: [Progression]?                // finish celebration
    @State private var quote = ""
    @State private var deloadActive = false                         // this is a deload week
    @State private var bumped: Set<String> = []                    // exercises auto-progressed this session
    @AppStorage("deloadAnchor") private var deloadAnchor = ""

    struct Progression: Identifiable { let id = UUID(); let name: String; let cue: String }

    init(day: PlanContent.Day, onDone: @escaping () -> Void) {
        self.day = day; self.onDone = onDone
        _exercises = State(initialValue: day.exercises.map { e in
            LoggedExercise(name: e.name, target: e.target, repRange: e.reps,
                           sets: (0..<max(1, e.sets)).map { _ in LoggedSet() })
        })
    }

    private var doneCount: Int { exercises.flatMap { $0.sets }.filter { $0.done }.count }
    private var totalSets: Int { exercises.flatMap { $0.sets }.count }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(exercises.indices, id: \.self) { i in exerciseCard(i) }
                    }
                    .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                footer
            }
            if let flash { flashBanner(flash) }
            if let progressions { celebration(progressions) }
        }
        .task { await loadLast() }
        .sensoryFeedback(.success, trigger: pulsedSets.count)
        .keyboardDone()
    }

    // Pre-fill weights from the last time each exercise was logged, applying progression
    // automatically: if you hit the top of the range last time → add the smallest jump;
    // on a deload week → drop to ~60% so you keep growing without grinding.
    private func loadLast() async {
        let logs = (try? await ScanAPI.shared.recentWorkouts(limit: 30)) ?? []
        var map: [String: [LoggedSet]] = [:]
        for log in logs {   // newest first
            for ex in log.exercises where map[ex.name] == nil {
                if ex.sets.contains(where: { $0.weight > 0 || $0.reps > 0 }) { map[ex.name] = ex.sets }
            }
        }
        let weeks = Deload.weeks(anchor: deloadAnchor, earliest: logs.last?.log_date)
        let deload = Deload.isDue(weeks)
        await MainActor.run {
            lastByExercise = map
            deloadActive = deload
            for i in exercises.indices {
                guard let last = map[exercises[i].name] else { continue }
                let ranges = RepRange.perSet(exercises[i].repRange, count: exercises[i].sets.count)
                for j in exercises[i].sets.indices where j < last.count {
                    let w = last[j].weight
                    guard w > 0 else { continue }
                    // Deload (JP): KEEP the weight — you just stop short of failure. No auto-add.
                    // Because deload reps land below the top of the range, the week after
                    // naturally rebuilds to your numbers before pushing past them.
                    if !deload, let range = ranges[j], last[j].reps >= range.high, last[j].reps > 0 {
                        exercises[i].sets[j].weight = w + Deload.increment(for: w)
                        bumped.insert(exercises[i].name)
                    } else {
                        exercises[i].sets[j].weight = w
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text(day.day).font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.txt)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                        .padding(8).background(Circle().fill(Theme.card))
                }
            }
            HStack {
                Text(day.focus).font(.system(size: 12)).foregroundStyle(Theme.mut)
                Spacer()
                Text("\(doneCount)/\(totalSets) sets").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.acc)
            }
            HStack(spacing: 6) {
                Image(systemName: deloadActive ? "wind" : "bolt.fill").font(.system(size: 10))
                    .foregroundStyle(deloadActive ? Theme.amber : Theme.acc)
                Text(deloadActive
                     ? "Deload week — same weights, but leave 2 reps in the tank (3–4 on the 15–20 sets). No failure. Recover, then go again."
                     : "Beat last session — every set to failure. Top of the rep range? Add a little weight.")
                    .font(.system(size: 11)).foregroundStyle(deloadActive ? Color(hex: 0xE6E0CF) : Theme.mut)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
        .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 8)
    }

    private func exerciseCard(_ i: Int) -> some View {
        let ranges = RepRange.perSet(exercises[i].repRange, count: exercises[i].sets.count)
        let rangeLabels = ranges.compactMap { $0?.label }.reduce(into: [String]()) { acc, l in
            if !acc.contains(l) { acc.append(l) }
        }
        let note = i < day.exercises.count ? day.exercises[i].note : nil
        let hasBackoff = exercises[i].sets.count > 1 && rangeLabels.count > 1   // top set + lighter back-off
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(exercises[i].name).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                Spacer()
                if !rangeLabels.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "target").font(.system(size: 9, weight: .bold))
                        Text("\(rangeLabels.joined(separator: " · ")) reps").font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Theme.acc.opacity(0.16))).foregroundStyle(Theme.acc)
                }
            }
            HStack(spacing: 6) {
                Text(exercises[i].target).font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                if bumped.contains(exercises[i].name) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up").font(.system(size: 8, weight: .heavy))
                        Text("weight added").font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.acc.opacity(0.16))).foregroundStyle(Theme.acc)
                }
            }
            if let note, !note.isEmpty {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "info.circle").font(.system(size: 9)).foregroundStyle(Theme.acc.opacity(0.8)).padding(.top, 1)
                    Text(note).font(.system(size: 10.5)).foregroundStyle(Color(hex: 0xC8C8CE)).lineSpacing(2)
                }
            }
            if let last = lastByExercise[exercises[i].name], !last.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 9)).foregroundStyle(Theme.mut)
                    Text("Last: " + last.prefix(exercises[i].sets.count).map { "\(Int($0.weight))×\($0.reps)" }.joined(separator: " · "))
                        .font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                }
            }
            ForEach(exercises[i].sets.indices, id: \.self) { j in
                setRow(i, j, range: ranges[j], tag: hasBackoff ? (j == 0 ? "Top set" : "Back-off") : nil)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
    }

    private func setRow(_ i: Int, _ j: Int, range: RepRange?, tag: String? = nil) -> some View {
        let set = exercises[i].sets[j]
        let last = lastByExercise[exercises[i].name]
        let lastReps = (last != nil && j < last!.count) ? last![j].reps : nil
        let beat = set.done && lastReps != nil && set.reps > lastReps!
        let topHit = !deloadActive && set.done && range != nil && set.reps >= range!.high && set.reps > 0
        let pulsing = pulsedSets.contains(set.id)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Set \(j + 1)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
                if let tag { Text(tag).font(.system(size: 8.5, weight: .bold)).foregroundStyle(Theme.acc.opacity(0.8)) }
            }
            .frame(width: 58, alignment: .leading)
            numField("lb", value: Binding(get: { exercises[i].sets[j].weight }, set: { exercises[i].sets[j].weight = $0 }))
            numField("reps", value: Binding(
                get: { Double(exercises[i].sets[j].reps) },
                set: { exercises[i].sets[j].reps = Int($0) }))
            if let lastReps, !set.done {
                Text("last \(lastReps)").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.mut)
            } else if topHit {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill").font(.system(size: 9))
                    Text("top").font(.system(size: 10, weight: .bold))
                }.foregroundStyle(Theme.acc)
            } else if beat {
                Text("PR").font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.acc)
            }
            Spacer()
            Button { toggle(i, j, range: range) } label: {
                Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24)).foregroundStyle(set.done ? Theme.acc : Theme.line)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 9).fill(pulsing ? Theme.acc.opacity(0.18) : .clear))
        .scaleEffect(pulsing ? 1.03 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pulsing)
    }

    // Mark a set done/undone, firing the progressive-overload feedback.
    private func toggle(_ i: Int, _ j: Int, range: RepRange?) {
        let wasDone = exercises[i].sets[j].done
        withAnimation(.easeOut(duration: 0.12)) { exercises[i].sets[j].done.toggle() }
        guard !wasDone, exercises[i].sets[j].done else { return }   // only celebrate on completing
        let set = exercises[i].sets[j]
        let last = lastByExercise[exercises[i].name]
        let lastReps = (last != nil && j < last!.count) ? last![j].reps : nil
        let beat = lastReps != nil && set.reps > lastReps!
        let topHit = !deloadActive && range != nil && set.reps >= range!.high && set.reps > 0
        if beat || topHit {
            pulsedSets.insert(set.id)
            Task { try? await Task.sleep(nanoseconds: 900_000_000); await MainActor.run { pulsedSets.remove(set.id) } }
        }
        if topHit {
            showFlash("Top of your range on \(exercises[i].name) — you're going up next session 🔥")
        }
    }

    private func showFlash(_ msg: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { flash = msg }
        Task { try? await Task.sleep(nanoseconds: 2_600_000_000)
            await MainActor.run { withAnimation { flash = nil } } }
    }

    private func numField(_ label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 4) {
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad).multilineTextAlignment(.center)
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                .frame(width: 46).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1)))
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.mut)
        }
    }

    private var footer: some View {
        Button { finish() } label: {
            HStack(spacing: 8) {
                if saving { ProgressView().tint(Color(hex: 0x0E0E10)) }
                Text("Finish session").font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity).padding(15)
            .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
            .foregroundStyle(Color(hex: 0x0E0E10))
        }
        .disabled(saving)
        .padding(.horizontal, 18).padding(.bottom, 12)
    }

    // Which exercises hit the top of their range → add weight next time.
    private func computeProgressions() -> [Progression] {
        guard !deloadActive else { return [] }   // deload weeks don't earn weight — you held back from failure
        return exercises.compactMap { ex in
            let ranges = RepRange.perSet(ex.repRange, count: ex.sets.count)
            let hit = ex.sets.indices.contains { j in
                guard let r = ranges[j] else { return false }
                return ex.sets[j].done && ex.sets[j].reps >= r.high && ex.sets[j].reps > 0
            }
            guard hit, let top = ranges.compactMap({ $0 }).first else { return nil }
            return Progression(name: ex.name, cue: "Hit \(top.high)+ reps — add a little weight")
        }
    }

    static let quotes = [
        "Discipline is choosing what you want most over what you want now.",
        "The work you just did is the work most people skip.",
        "Consistency is the cheat code. You just used it.",
        "Small steps, every session. That's how a physique gets built.",
        "You don't find time to train — you make it. And you did.",
        "Showing up on the average days is what makes you exceptional.",
    ]

    private func finish() {
        saving = true
        Task {
            try? await ScanAPI.shared.logWorkout(dayLabel: day.day, exercises: exercises)
            await MainActor.run {
                saving = false
                quote = Self.quotes.randomElement() ?? Self.quotes[0]
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { progressions = computeProgressions() }
            }
        }
    }

    // MARK: overlays
    private func flashBanner(_ msg: String) -> some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").font(.system(size: 13)).foregroundStyle(Color(hex: 0x0E0E10))
                Text(msg).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Color(hex: 0x0E0E10))
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Capsule().fill(Theme.acc))
            .shadow(color: Theme.acc.opacity(0.4), radius: 12)
            .padding(.horizontal, 22).padding(.top, 8)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func celebration(_ wins: [Progression]) -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color(hex: 0xFF7A1A).opacity(0.16)).frame(width: 84, height: 84)
                    FireFlame(size: 46, flare: true)
                }
                Text("Session logged").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.txt)
                Text("“\(quote)”")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Color(hex: 0xD2D2D8))
                    .multilineTextAlignment(.center).lineSpacing(2).padding(.horizontal, 4)
                if !wins.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOU EARNED MORE WEIGHT — NEXT SESSION GO HEAVIER ON:")
                            .font(.system(size: 9.5, weight: .bold)).tracking(0.5).foregroundStyle(Theme.mut)
                        ForEach(wins) { w in
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.up.circle.fill").font(.system(size: 15)).foregroundStyle(Theme.acc)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(w.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                                    Text(w.cue).font(.system(size: 11)).foregroundStyle(Theme.mut)
                                }
                                Spacer()
                            }
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                        }
                    }
                }
                Button { onDone(); dismiss() } label: {
                    Text("Let's go").font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(14)
                        .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
                        .foregroundStyle(Color(hex: 0x0E0E10))
                }
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.bg).overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.acc.opacity(0.3), lineWidth: 1)))
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
        .sensoryFeedback(.success, trigger: progressions != nil)
    }
}
