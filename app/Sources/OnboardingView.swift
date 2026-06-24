import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var data = OnboardingData()
    @State private var stepIndex = 0
    @State private var saving = false
    @State private var error: String?

    private var step: OnbStep { OnbStep.allCases[stepIndex] }
    private var total: Int { OnbStep.allCases.count }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(step.title).font(.system(size: 25, weight: .heavy)).foregroundStyle(Theme.txt)
                            Text(step.subtitle).font(.system(size: 13)).foregroundStyle(Theme.mut)
                        }
                        stepContent
                        if let error {
                            Text(error).font(.system(size: 12)).foregroundStyle(Theme.red)
                        }
                    }
                    .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                footer
            }
        }
    }

    // MARK: header (progress + back)
    private var header: some View {
        HStack(spacing: 12) {
            Button { back() } label: {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(stepIndex == 0 ? Theme.line : Theme.txt)
            }
            .disabled(stepIndex == 0)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line).frame(height: 5)
                    Capsule().fill(Theme.acc)
                        .frame(width: geo.size.width * CGFloat(stepIndex + 1) / CGFloat(total), height: 5)
                        .animation(.spring(response: 0.4), value: stepIndex)
                }
            }
            .frame(height: 5)
            Text("\(stepIndex + 1)/\(total)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
        }
        .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 6)
    }

    // MARK: footer (continue)
    private var footer: some View {
        Button { advance() } label: {
            HStack(spacing: 8) {
                if saving { ProgressView().tint(Color(hex: 0x0E0E10)) }
                Text(stepIndex == total - 1 ? "Finish" : "Continue")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity).padding(15)
            .background(RoundedRectangle(cornerRadius: 13).fill(canAdvance ? Theme.acc : Theme.line))
            .foregroundStyle(canAdvance ? Color(hex: 0x0E0E10) : Theme.mut)
        }
        .disabled(!canAdvance || saving)
        .padding(.horizontal, 22).padding(.bottom, 10)
    }

    // MARK: per-step content
    @ViewBuilder private var stepContent: some View {
        switch step {
        case .sex:        singleSelect(OnbOptions.sex, data.sex) { data.sex = $0 }
        case .goal:       singleSelect(OnbOptions.goal, data.goal) { data.goal = $0 }
        case .focus:      multiSelect(OnbOptions.focus)
        case .experience: singleSelect(OnbOptions.experience, data.experience) { data.experience = $0 }
        case .days:       singleSelect(OnbOptions.days, data.daysPerWeek.map(String.init)) { data.daysPerWeek = Int($0) }
        case .equipment:  singleSelect(OnbOptions.equipment, data.equipment) { data.equipment = $0 }
        case .height:     measure(value: $data.heightCm, range: 140...215, units: ["cm", "ft"], format: heightLabel)
        case .weight:     measure(value: $data.weightKg, range: 40...180, units: ["kg", "lb"], format: weightLabel)
        case .age:        ageStep
        }
    }

    private func singleSelect(_ opts: [Option], _ selected: String?, _ set: @escaping (String) -> Void) -> some View {
        VStack(spacing: 10) {
            ForEach(opts) { o in
                optionCard(o.label, o.sub, selected: selected == o.id) { set(o.id) }
            }
        }
    }

    private func multiSelect(_ opts: [Option]) -> some View {
        VStack(spacing: 10) {
            ForEach(opts) { o in
                optionCard(o.label, o.sub, selected: data.focus.contains(o.id)) {
                    if data.focus.contains(o.id) { data.focus.remove(o.id) } else { data.focus.insert(o.id) }
                }
            }
        }
    }

    private func optionCard(_ title: String, _ subtitle: String?, selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.txt)
                    if let subtitle { Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.mut) }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(Theme.acc)
                } else {
                    Circle().stroke(Theme.line, lineWidth: 1.5).frame(width: 20, height: 20)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(selected ? Theme.acc.opacity(0.08) : Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Theme.acc : Theme.line, lineWidth: selected ? 1.5 : 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: measure (height/weight) — big readout + slider + unit toggle
    @State private var unit = 0
    private func measure(value: Binding<Double>, range: ClosedRange<Double>, units: [String], format: @escaping (Double, Int) -> String) -> some View {
        VStack(spacing: 22) {
            Text(format(value.wrappedValue, unit))
                .font(.system(size: 44, weight: .heavy)).foregroundStyle(Theme.txt)
                .frame(maxWidth: .infinity)
            Slider(value: value, in: range, step: 1).tint(Theme.acc)
            HStack(spacing: 8) {
                ForEach(units.indices, id: \.self) { i in
                    Button { unit = i } label: {
                        Text(units[i]).font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 16).padding(.vertical, 7)
                            .background(Capsule().fill(unit == i ? Theme.acc : Theme.card))
                            .foregroundStyle(unit == i ? Color(hex: 0x0E0E10) : Theme.mut)
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 20)
    }

    private var ageStep: some View {
        VStack(spacing: 22) {
            Text("\(data.age)").font(.system(size: 44, weight: .heavy)).foregroundStyle(Theme.txt)
                .frame(maxWidth: .infinity)
            Slider(value: Binding(get: { Double(data.age) }, set: { data.age = Int($0) }), in: 14...90, step: 1).tint(Theme.acc)
            Text("years").font(.system(size: 13)).foregroundStyle(Theme.mut)
        }
        .padding(.top, 20)
    }

    private func heightLabel(_ cm: Double, _ u: Int) -> String {
        if u == 0 { return "\(Int(cm)) cm" }
        let totalIn = cm / 2.54
        return "\(Int(totalIn) / 12)'\(Int(totalIn.rounded()) % 12)\""
    }
    private func weightLabel(_ kg: Double, _ u: Int) -> String {
        u == 0 ? "\(Int(kg)) kg" : "\(Int((kg * 2.20462).rounded())) lb"
    }

    // MARK: nav
    private var canAdvance: Bool {
        switch step {
        case .sex: return data.sex != nil
        case .goal: return data.goal != nil
        case .focus: return !data.focus.isEmpty
        case .experience: return data.experience != nil
        case .days: return data.daysPerWeek != nil
        case .equipment: return data.equipment != nil
        case .height, .weight, .age: return true
        }
    }

    private func back() {
        unit = 0
        if stepIndex > 0 { withAnimation { stepIndex -= 1 } }
    }
    private func advance() {
        unit = 0
        error = nil
        if stepIndex < total - 1 { withAnimation { stepIndex += 1 }; return }
        // last step → persist
        saving = true
        Task {
            do {
                try await ScanAPI.shared.saveProfile(data.payload)
                await MainActor.run { saving = false; onComplete() }
            } catch {
                await MainActor.run { saving = false; self.error = "Couldn't save: \(error.localizedDescription)" }
            }
        }
    }
}

#Preview { OnboardingView(onComplete: {}).preferredColorScheme(.dark) }
