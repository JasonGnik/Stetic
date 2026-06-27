import SwiftUI

// Asked before regenerating / finishing a block: your plan changes with you, so re-pick
// goal, days/week (you may have more time now) and pace, then rebuild from the latest scan.
struct RegenPlanSheet: View {
    let finishing: Bool
    let currentDays: Int
    let onBuild: (_ goal: String, _ days: Int, _ pace: String, _ weightKg: Double, _ goalWeightKg: Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var goal = "gain_muscle"
    @State private var days: Int
    @State private var pace = "recommended"
    @State private var weightKg = 80.0
    @State private var goalKg = 78.0

    init(finishing: Bool, currentDays: Int, onBuild: @escaping (String, Int, String, Double, Double) -> Void) {
        self.finishing = finishing; self.currentDays = currentDays; self.onBuild = onBuild
        _days = State(initialValue: max(2, min(6, currentDays)))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text(finishing ? "Finish & rebuild" : "New plan")
                        .font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.txt)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                            .padding(8).background(Circle().fill(Theme.card))
                    }
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Your plan changes with you. Set these and we'll rebuild from your latest scan.")
                            .font(.system(size: 13)).foregroundStyle(Theme.mut).padding(.horizontal, 20)

                        section("YOUR GOAL") {
                            VStack(spacing: 10) {
                                ForEach(OnbOptions.goal) { o in
                                    selectRow(o.label, o.sub, selected: goal == o.id) { goal = o.id }
                                }
                            }
                        }
                        section("DAYS PER WEEK") {
                            HStack(spacing: 8) {
                                ForEach(2...6, id: \.self) { n in
                                    Button { days = n } label: {
                                        Text("\(n)").font(.system(size: 16, weight: .bold))
                                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                                            .background(RoundedRectangle(cornerRadius: 12).fill(days == n ? Theme.acc : Theme.card))
                                            .foregroundStyle(days == n ? Color(hex: 0x0E0E10) : Theme.txt)
                                    }.buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        section("HOW FAST") {
                            VStack(spacing: 10) {
                                ForEach(OnbOptions.pace) { o in
                                    selectRow(o.label, o.sub, selected: pace == o.id) { pace = o.id }
                                }
                            }
                        }
                        section("BODY WEIGHT") { weightField($weightKg) }
                        section("GOAL WEIGHT") { weightField($goalKg) }
                    }
                    .padding(.vertical, 14)
                }
                .scrollIndicators(.hidden)

                Button { onBuild(goal, days, pace, weightKg, goalKg); dismiss() } label: {
                    Text(finishing ? "Finish & build my plan" : "Build my plan")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(15)
                        .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
                        .foregroundStyle(Color(hex: 0x0E0E10))
                }
                .padding(.horizontal, 20).padding(.bottom, 14)
            }
        }
        .task {   // pre-fill from the stored profile
            if let i = try? await ScanAPI.shared.planInputs() {
                if let g = i.goal { goal = g }
                if let p = i.pace { pace = p }
                if let d = i.days { days = max(2, min(6, d)) }
                if let w = i.weightKg { weightKg = w }
                if let gw = i.goalWeightKg { goalKg = gw }
            }
        }
    }

    private func weightField(_ value: Binding<Double>) -> some View {
        VStack(spacing: 8) {
            Text("\(Int((value.wrappedValue * 2.20462).rounded())) lb")
                .font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.txt)
            Slider(value: value, in: 40...160, step: 0.5).tint(Theme.acc)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.mut).padding(.horizontal, 20)
            content()
        }
    }
    private func selectRow(_ title: String, _ sub: String?, selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                    if let sub { Text(sub).font(.system(size: 12)).foregroundStyle(Theme.mut) }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20)).foregroundStyle(selected ? Theme.acc : Theme.line)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Theme.acc.opacity(0.08) : Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Theme.acc : Theme.line, lineWidth: selected ? 1.5 : 1)))
        }
        .buttonStyle(.plain).padding(.horizontal, 20)
    }
}
