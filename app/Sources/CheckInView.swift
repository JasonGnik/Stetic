import SwiftUI

// Daily readiness check-in (mood · confidence in the goal · feel like training/
// sticking to plan). On low days it nudges them to show up and shows their own
// track record + a hard-day quote.
struct CheckInView: View {
    let trainingDay: Bool
    let history: [CheckIn]
    let workoutDates: [String]
    var onStartSession: () -> Void
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var mood = 0
    @State private var confidence = 0
    @State private var readiness = 0
    @State private var phase: Phase = .ask
    @State private var saving = false
    enum Phase { case ask, result }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(phase == .ask ? "Daily check-in" : "Locked in").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                        .padding(8).background(Circle().fill(Theme.card))
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 8)
            if phase == .ask { askView } else { resultView }
        }
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.large])
    }

    // MARK: ask
    private var askView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                question("How's your mood today?") {
                    scale($mood, low: "Rough", high: "Great")
                }
                question("How confident are you about hitting your goal?") {
                    scale($confidence, low: "Not really", high: "Totally")
                }
                question(trainingDay ? "Feel like training today?" : "Feel like sticking to your plan today?") {
                    HStack(spacing: 8) {
                        readinessButton("Not really", 1); readinessButton("Maybe", 3); readinessButton("Let's go", 5)
                    }
                }
                Button { Task { await submit() } } label: {
                    HStack(spacing: 6) {
                        if saving { ProgressView().tint(Color(hex: 0x0E0E10)) }
                        Text("Continue").font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(canSubmit ? Theme.acc : Theme.line))
                    .foregroundStyle(canSubmit ? Color(hex: 0x0E0E10) : Theme.mut)
                }
                .disabled(!canSubmit || saving)
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var canSubmit: Bool { mood > 0 && confidence > 0 && readiness > 0 }

    private func question<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
            content()
        }
    }

    private func scale(_ value: Binding<Int>, low: String, high: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    Button { value.wrappedValue = i } label: {
                        Circle().fill(value.wrappedValue >= i ? Theme.acc : Theme.card)
                            .overlay(Circle().stroke(value.wrappedValue >= i ? .clear : Theme.line, lineWidth: 1))
                            .frame(height: 34).frame(maxWidth: .infinity)
                    }
                }
            }
            HStack { Text(low).font(.system(size: 10)).foregroundStyle(Theme.mut); Spacer(); Text(high).font(.system(size: 10)).foregroundStyle(Theme.mut) }
        }
    }

    private func readinessButton(_ label: String, _ v: Int) -> some View {
        Button { readiness = v } label: {
            Text(label).font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(readiness == v ? Theme.acc : Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(readiness == v ? .clear : Theme.line, lineWidth: 1)))
                .foregroundStyle(readiness == v ? Color(hex: 0x0E0E10) : Theme.txt)
        }
    }

    // MARK: result
    private var lowDay: Bool { readiness <= 2 }
    private var historyLine: String? {
        let lows = history.filter { $0.readiness <= 2 }
        guard lows.count >= 2 else { return nil }
        let pushed = lows.filter { workoutDates.contains($0.log_date ?? "") }.count
        guard pushed >= 1 else { return nil }
        return "The last \(lows.count) times you felt like this, you showed up \(pushed)× — and you were glad you did."
    }

    private var resultView: some View {
        let quote = Quotes.forReadiness(readiness)
        return ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill((lowDay ? Color(hex: 0xFF7A1A) : Theme.acc).opacity(0.16)).frame(width: 80, height: 80)
                    if lowDay { FireFlame(size: 40, flare: true) }
                    else { Image(systemName: "bolt.fill").font(.system(size: 38)).foregroundStyle(Theme.acc) }
                }
                Text(lowDay ? "This is the day that counts." : "Let's make it count.")
                    .font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.txt).multilineTextAlignment(.center)
                Text(lowDay
                     ? "Showing up when you don't feel like it is exactly what rewires the habit. The motivation comes after you start."
                     : "You've got the momentum — go put it to work.")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut).multilineTextAlignment(.center).lineSpacing(2).padding(.horizontal, 8)

                if let line = historyLine {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 13)).foregroundStyle(Theme.acc).padding(.top, 1)
                        Text(line).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Color(hex: 0xD2D2D8)).lineSpacing(2)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "quote.opening").font(.system(size: 14)).foregroundStyle(Theme.acc.opacity(0.7))
                    Text(quote.text).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: 0xD2D2D8)).lineSpacing(3)
                    Text("— \(quote.who)").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))

                if trainingDay {
                    Button { onStartSession(); dismiss() } label: {
                        Text("Start today's session").font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity).padding(14)
                            .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc)).foregroundStyle(Color(hex: 0x0E0E10))
                    }
                }
                Button { onDone(); dismiss() } label: {
                    Text(trainingDay ? "Not now" : "Done").font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity).padding(12)
                        .foregroundStyle(trainingDay ? Theme.mut : Color(hex: 0x0E0E10))
                        .background(trainingDay ? Color.clear : Theme.acc, in: RoundedRectangle(cornerRadius: 13))
                }
            }
            .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.success, trigger: phase)
    }

    private func submit() async {
        saving = true
        try? await ScanAPI.shared.saveCheckIn(mood: mood, confidence: confidence, readiness: readiness, trainingDay: trainingDay)
        await MainActor.run { saving = false; withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .result } }
    }
}
