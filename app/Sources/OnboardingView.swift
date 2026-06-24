import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var data = OnboardingData()
    @State private var stepIndex = Int(ProcessInfo.processInfo.environment["STETIC_ONB_STEP"] ?? "") ?? 0
    @State private var saving = false
    @State private var error: String?

    private var step: OnbStep { OnbStep.allCases[stepIndex] }
    private var total: Int { OnbStep.allCases.count }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if step.isInterstitial {
                interstitialView
            } else {
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
    }

    // MARK: interstitials (callback, social proof) — full-screen, more cinematic
    private var interstitialView: some View {
        VStack(spacing: 0) {
            HStack {
                Button { back() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                }
                Spacer()
            }
            .padding(.horizontal, 22).padding(.top, 8)
            Spacer()
            Group {
                switch step {
                case .callback: callbackContent
                case .socialProof: socialProofContent
                default: EmptyView()
                }
            }
            .padding(.horizontal, 30)
            Spacer()
            Button { advance() } label: {
                Text("Continue").font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity).padding(15)
                    .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
                    .foregroundStyle(Color(hex: 0x0E0E10))
            }
            .padding(.horizontal, 22).padding(.bottom, 14)
        }
    }

    private var callbackContent: some View {
        let cb = Callbacks.pick(data.obstacles)
        return VStack(spacing: 18) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 46, weight: .semibold)).foregroundStyle(Theme.acc)
            Text(cb.headline)
                .font(.system(size: 26, weight: .heavy)).multilineTextAlignment(.center)
                .foregroundStyle(Theme.txt)
            Text(brandLimed(cb.body))
                .font(.system(size: 15)).multilineTextAlignment(.center).lineSpacing(4)
                .foregroundStyle(Theme.mut)
        }
    }

    // NOTE: count + reviews are placeholders for real app metrics / testimonials.
    private var socialProofContent: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("12,000+").font(.system(size: 54, weight: .heavy)).foregroundStyle(Theme.acc)
                Text("physiques analyzed").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
            }
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill").font(.system(size: 13)).foregroundStyle(Theme.acc)
                }
            }
            VStack(spacing: 10) {
                reviewCard("Finally an app that told me the truth. My back was killing my whole look.", "Marcus")
                reviewCard("Went from a 5.8 to Diamond in 8 weeks. The plan just works.", "Dev")
            }
            .padding(.top, 6)
        }
    }

    private func reviewCard(_ text: String, _ name: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(Theme.acc)
                }
            }
            Text("“\(text)”").font(.system(size: 13)).foregroundStyle(Color(hex: 0xD2D2D8)).lineSpacing(2)
            Text("— \(name)").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
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
        case .name:       nameField
        case .sex:        singleSelect(OnbOptions.sex, data.sex) { data.sex = $0 }
        case .goal:       singleSelect(OnbOptions.goal, data.goal) { data.goal = $0 }
        case .obstacles:  multiSelect(OnbOptions.obstacles, data.obstacles) { toggle(&data.obstacles, $0) }
        case .focus:      multiSelect(OnbOptions.focus, data.focus) { toggle(&data.focus, $0) }
        case .experience: singleSelect(OnbOptions.experience, data.experience) { data.experience = $0 }
        case .days:       singleSelect(OnbOptions.days, data.daysPerWeek.map(String.init)) { data.daysPerWeek = Int($0) }
        case .equipment:  singleSelect(OnbOptions.equipment, data.equipment) { data.equipment = $0 }
        case .height:     measure(value: $data.heightCm, range: 140...215, units: ["ft", "cm"], format: heightLabel)
        case .weight:     measure(value: $data.weightKg, range: 40...180, units: ["lb", "kg"], format: weightLabel)
        case .age:        ageStep
        case .attribution: singleSelect(OnbOptions.attribution, data.attribution) { data.attribution = $0 }
        case .callback, .socialProof: EmptyView()   // rendered by interstitialView
        }
    }

    private func singleSelect(_ opts: [Option], _ selected: String?, _ set: @escaping (String) -> Void) -> some View {
        VStack(spacing: 10) {
            ForEach(opts) { o in
                optionCard(o.label, o.sub, selected: selected == o.id) {
                    withAnimation(.easeOut(duration: 0.12)) { set(o.id) }
                    // auto-advance — fewer taps (single-select only)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { advance() }
                }
            }
        }
    }

    private func multiSelect(_ opts: [Option], _ selected: Set<String>, _ onTap: @escaping (String) -> Void) -> some View {
        VStack(spacing: 10) {
            ForEach(opts) { o in
                optionCard(o.label, o.sub, selected: selected.contains(o.id)) { onTap(o.id) }
            }
        }
    }

    private func toggle(_ set: inout Set<String>, _ id: String) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
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

    private var nameField: some View {
        TextField("", text: $data.name,
                  prompt: Text("Your name").foregroundStyle(Theme.mut))
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(Theme.txt)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .onSubmit { if canAdvance { advance() } }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
            )
            .padding(.top, 10)
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
        if u == 1 { return "\(Int(cm)) cm" }            // u==0 → ft (default)
        let totalIn = (cm / 2.54).rounded()
        return "\(Int(totalIn) / 12)'\(Int(totalIn) % 12)\""
    }
    private func weightLabel(_ kg: Double, _ u: Int) -> String {
        u == 1 ? "\(Int(kg)) kg" : "\(Int((kg * 2.20462).rounded())) lb"   // u==0 → lb (default)
    }

    // MARK: nav
    private var canAdvance: Bool {
        switch step {
        case .name: return !data.name.trimmingCharacters(in: .whitespaces).isEmpty
        case .sex: return data.sex != nil
        case .goal: return data.goal != nil
        case .obstacles: return true   // optional
        case .focus: return true   // optional — scan finds weak points
        case .experience: return data.experience != nil
        case .days: return data.daysPerWeek != nil
        case .equipment: return data.equipment != nil
        case .height, .weight, .age: return true
        case .attribution: return data.attribution != nil
        case .callback, .socialProof: return true
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
