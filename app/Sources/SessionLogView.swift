import SwiftUI

// Log a training session: tick off sets, enter weight × reps, finish to bank the streak.
struct SessionLogView: View {
    let day: PlanContent.Day
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var exercises: [LoggedExercise]
    @State private var saving = false

    init(day: PlanContent.Day, onDone: @escaping () -> Void) {
        self.day = day; self.onDone = onDone
        _exercises = State(initialValue: day.exercises.map { e in
            LoggedExercise(name: e.name, target: e.target,
                           sets: (0..<max(1, e.sets)).map { _ in LoggedSet() })
        })
    }

    private var doneCount: Int { exercises.flatMap { $0.sets }.filter { $0.done }.count }
    private var totalSets: Int { exercises.flatMap { $0.sets }.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(exercises.indices, id: \.self) { i in exerciseCard(i) }
                }
                .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            footer
        }
        .background(Theme.bg.ignoresSafeArea())
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
        }
        .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 8)
    }

    private func exerciseCard(_ i: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(exercises[i].name).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                Spacer()
                Text(exercises[i].target).font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.line)).foregroundStyle(Theme.mut)
            }
            ForEach(exercises[i].sets.indices, id: \.self) { j in setRow(i, j) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
    }

    private func setRow(_ i: Int, _ j: Int) -> some View {
        let done = exercises[i].sets[j].done
        return HStack(spacing: 10) {
            Text("Set \(j + 1)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut).frame(width: 44, alignment: .leading)
            numField("lb", value: Binding(get: { exercises[i].sets[j].weight }, set: { exercises[i].sets[j].weight = $0 }))
            numField("reps", value: Binding(
                get: { Double(exercises[i].sets[j].reps) },
                set: { exercises[i].sets[j].reps = Int($0) }))
            Spacer()
            Button {
                withAnimation(.easeOut(duration: 0.12)) { exercises[i].sets[j].done.toggle() }
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24)).foregroundStyle(done ? Theme.acc : Theme.line)
            }
        }
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

    private func finish() {
        saving = true
        Task {
            try? await ScanAPI.shared.logWorkout(dayLabel: day.day, exercises: exercises)
            await MainActor.run { saving = false; onDone(); dismiss() }
        }
    }
}
