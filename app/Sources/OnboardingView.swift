import SwiftUI
import UserNotifications
import PhotosUI

struct OnboardingView: View {
    var onComplete: (OnboardingData) -> Void   // answers held locally; saved after sign-in
    @State private var data = OnboardingData()
    @State private var stepIndex = Int(ProcessInfo.processInfo.environment["STETIC_ONB_STEP"] ?? "") ?? 0
    @State private var saving = false
    @State private var error: String?
    @State private var seededGoalWeight = false
    @State private var splitPhoto: PhotosPickerItem?
    @State private var readingSplit = false

    private var step: OnbStep { OnbStep.allCases[stepIndex] }
    private var total: Int { OnbStep.allCases.count }

    // Single-select steps auto-advance on tap — no Continue button needed.
    private var needsContinue: Bool {
        switch step {
        case .sex, .goal, .pace, .activity, .experience, .days, .equipment, .attribution, .reminders,
             .resultsFeeling, .triedPlan: return false   // single-select auto-advances
        default: return true
        }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if step == .transformation {
                TransformationScreen(data: data, onContinue: { advance() }, onBack: { back() })
            } else if step.isInterstitial {
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
                    if needsContinue { footer }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: stepIndex)
    }

    // MARK: interstitials (callback, social proof) — full-screen, more cinematic
    private var interstitialView: some View {
        VStack(spacing: 0) {
            HStack {
                if stepIndex > 0 {
                    Button { back() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 22).padding(.top, 8)
            Spacer()
            Group {
                switch step {
                case .callback: callbackContent
                case .doom: doomContent
                case .aha: ahaContent
                case .trainingFix: trainingFixContent
                case .nutrition: nutritionContent
                case .socialProof: socialProofContent
                default: EmptyView()
                }
            }
            .padding(.horizontal, 30)
            Spacer()
            Button { advance() } label: {
                Text(interstitialCTA).font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity).padding(15)
                    .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
                    .foregroundStyle(Color(hex: 0x0E0E10))
            }
            .padding(.horizontal, 22).padding(.bottom, 14)
        }
    }

    private var interstitialCTA: String {
        switch step {
        case .doom: return "I'm ready"
        case .aha: return "Show me how"
        case .trainingFix, .nutrition: return "Keep going"
        default: return "Continue"
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

    // MARK: DOOM — two roads
    private var doomContent: some View {
        VStack(spacing: 20) {
            Text("A year from now.")
                .font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.txt)
            VStack(spacing: 12) {
                roadCard(icon: "arrow.uturn.backward", tint: Theme.red, head: "Do nothing",
                         body: "Same body in the mirror. Another year gone.")
                roadCard(icon: "flame.fill", tint: Theme.acc, head: "Start now",
                         body: "The best you've ever looked — in 12 weeks.")
            }
            Text("The time will pass anyways.")
                .font(.system(size: 15, weight: .semibold)).multilineTextAlignment(.center)
                .foregroundStyle(Theme.mut).padding(.top, 4)
        }
    }
    private func roadCard(icon: String, tint: Color, head: String, body: String) -> some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 11, style: .continuous).fill(tint.opacity(0.16))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: icon).font(.system(size: 19, weight: .bold)).foregroundStyle(tint))
            VStack(alignment: .leading, spacing: 2) {
                Text(head).font(.system(size: 13, weight: .bold)).foregroundStyle(tint)
                Text(body).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
            }
            Spacer()
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.4), lineWidth: 1)))
    }

    // MARK: AHA — "how it works" auto-play demo (scan → weak points → plan → progress)
    private var ahaContent: some View {
        HowItWorksDemo()
    }

    // MARK: TRAINING FIX — years of waiting stop now (+ mountain)
    private var trainingFixContent: some View {
        TrainingFixScene(years: Int(data.timeWantedYears))
    }

    // MARK: NUTRITION — show the meal scan, short copy, freedom
    private var nutritionContent: some View {
        VStack(spacing: 18) {
            NutritionMini()
            Text("No chicken-and-broccoli. Eat real food.")
                .font(.system(size: 24, weight: .heavy)).multilineTextAlignment(.center).foregroundStyle(Theme.txt)
            Text(brandLimed("Scan a meal, hit your macros, still eat out with friends. Stick to it most of the time — no starving, no obsessing. Just on track, every day."))
                .font(.system(size: 14.5)).multilineTextAlignment(.center).lineSpacing(3).foregroundStyle(Theme.mut)
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
                reviewCard("Leaner than I've ever been — first time my abs actually show. It knew exactly what was holding me back.", "Marcus")
                reviewCard("Climbed from Gold to Diamond in 8 weeks, training smarter and spending less time in the gym.", "Dev")
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
        case .motivation: multiSelect(OnbOptions.motivation, data.motivation) { toggle(&data.motivation, $0) }
        case .timeWanted: timeWantedStep
        case .resultsFeeling: singleSelect(OnbOptions.resultsFeeling, data.resultsFeeling) { data.resultsFeeling = $0 }
        case .triedPlan:  singleSelect(OnbOptions.triedPlan, data.triedPlan) { data.triedPlan = $0 }
        case .sex:        singleSelect(OnbOptions.sex, data.sex) { data.sex = $0 }
        case .goal:       singleSelect(OnbOptions.goal, data.goal) { data.goal = $0 }
        case .pace:       singleSelect(OnbOptions.pace, data.pace) { data.pace = $0 }
        case .activity:   singleSelect(OnbOptions.activity, data.activity) { data.activity = $0 }
        case .obstacles:  multiSelect(OnbOptions.obstacles, data.obstacles) { toggle(&data.obstacles, $0) }
        case .experience: singleSelect(OnbOptions.experience, data.experience) { data.experience = $0 }
        case .currentSplit: splitField
        case .days:       singleSelect(OnbOptions.days, data.daysPerWeek.map(String.init)) { data.daysPerWeek = Int($0) }
        case .equipment:  singleSelect(OnbOptions.equipment, data.equipment) { data.equipment = $0 }
        case .equipmentDetail: multiSelect(OnbOptions.equipmentItems, data.equipmentItems) { toggle(&data.equipmentItems, $0) }
        case .height:     measure(value: $data.heightCm, range: 140...215, units: ["ft", "cm"], format: heightLabel)
        case .weight:     measure(value: $data.weightKg, range: 40...160, units: ["lb", "kg"], format: weightLabel, step: 0.5)
        case .goalWeight: measure(value: $data.goalWeightKg, range: 40...160, units: ["lb", "kg"], format: weightLabel, step: 0.5)
        case .age:        ageStep
        case .attribution: singleSelect(OnbOptions.attribution, data.attribution) { data.attribution = $0 }
        case .reminders:  remindersStep
        default:          EmptyView()   // interstitials rendered by interstitialView
        }
    }

    private func singleSelect(_ opts: [Option], _ selected: String?, _ set: @escaping (String) -> Void) -> some View {
        VStack(spacing: 10) {
            ForEach(opts) { o in
                optionCard(o.label, o.sub, icon: o.icon, tint: o.tint, selected: selected == o.id) {
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
                optionCard(o.label, o.sub, icon: o.icon, tint: o.tint, selected: selected.contains(o.id)) { onTap(o.id) }
            }
        }
    }

    private func toggle(_ set: inout Set<String>, _ id: String) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

    private func optionCard(_ title: String, _ subtitle: String?, icon: String? = nil, tint: Color? = nil,
                            selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                if let icon {
                    let c = tint ?? Theme.acc
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(c.opacity(0.16))
                        .frame(width: 46, height: 46)
                        .overlay(Image(systemName: icon).font(.system(size: 21, weight: .semibold)).foregroundStyle(c))
                }
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
    private func measure(value: Binding<Double>, range: ClosedRange<Double>, units: [String], format: @escaping (Double, Int) -> String, step: Double = 1) -> some View {
        VStack(spacing: 22) {
            Text(format(value.wrappedValue, unit))
                .font(.system(size: 44, weight: .heavy)).foregroundStyle(Theme.txt)
                .frame(maxWidth: .infinity)
            Slider(value: value, in: range, step: step).tint(Theme.acc)
                .sensoryFeedback(.selection, trigger: value.wrappedValue)
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

    // Free-text current routine (optional). Example chips make it effortless.
    private var splitField: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if data.currentSplit.isEmpty {
                    Text("e.g. PPL 6×/week, or Arnold split, or “bro split — chest Mon, back Tue…”")
                        .font(.system(size: 15)).foregroundStyle(Theme.mut)
                        .padding(.horizontal, 16).padding(.vertical, 18)
                }
                TextEditor(text: $data.currentSplit)
                    .font(.system(size: 15)).foregroundStyle(Theme.txt)
                    .scrollContentBackground(.hidden)
                    .frame(height: 120)
                    .padding(.horizontal, 11).padding(.vertical, 10)
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1)))
            PhotosPicker(selection: $splitPhoto, matching: .images) {
                HStack(spacing: 8) {
                    if readingSplit { ProgressView().tint(Theme.acc) }
                    else { Image(systemName: "photo.on.rectangle.angled").font(.system(size: 14, weight: .semibold)) }
                    Text(readingSplit ? "Reading your routine…" : "Have it written down? Upload a photo")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.acc)
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.acc.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.acc.opacity(0.35), lineWidth: 1)))
            }
            .disabled(readingSplit)
            Text("Optional — but the more you tell us, the sharper the analysis of what's holding you back.")
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
        }
        .padding(.top, 6)
        .onChange(of: splitPhoto) { _, v in Task { await readSplitPhoto(v) } }
    }

    private func readSplitPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        readingSplit = true
        defer { readingSplit = false; splitPhoto = nil }
        guard let d = try? await item.loadTransferable(type: Data.self) else { return }
        let jpeg = UIImage(data: d)?.jpegData(compressionQuality: 0.8) ?? d
        if let text = try? await ScanAPI.shared.readSplit(.init(mimeType: "image/jpeg", dataB64: jpeg.base64EncodedString())),
           !text.isEmpty {
            await MainActor.run { data.currentSplit = text }
        }
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

    // Reminder opt-in — selecting "yes" fires the system notification prompt, then advances.
    private var remindersStep: some View {
        VStack(spacing: 10) {
            ForEach(OnbOptions.reminders) { o in
                optionCard(o.label, o.sub, selected: data.reminders == (o.id == "yes")) {
                    data.reminders = (o.id == "yes")
                    if data.reminders {
                        NotificationManager.enableTrainingReminders(daysPerWeek: data.daysPerWeek ?? 4)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { advance() }
                }
            }
        }
    }

    private var ageStep: some View {
        VStack(spacing: 22) {
            Text("\(data.age)").font(.system(size: 44, weight: .heavy)).foregroundStyle(Theme.txt)
                .frame(maxWidth: .infinity)
            Slider(value: Binding(get: { Double(data.age) }, set: { data.age = Int($0) }), in: 14...90, step: 1).tint(Theme.acc)
                .sensoryFeedback(.selection, trigger: data.age)
            Text("years").font(.system(size: 13)).foregroundStyle(Theme.mut)
        }
        .padding(.top, 20)
    }

    // How long they've WANTED to change — the "damn, X years, why haven't I?" hook.
    private var timeWantedStep: some View {
        let yrs = data.timeWantedYears
        let label: String = yrs < 1 ? "A few months"
            : yrs >= 15 ? "15+ years"
            : "\(Int(yrs)) " + (Int(yrs) == 1 ? "year" : "years")
        let gut: String = yrs < 1 ? "The best time to start is now."
            : yrs < 3 ? "Long enough. Let's make it count."
            : yrs < 7 ? "That's a long time to keep wishing for it."
            : "Years of wanting it. Imagine if you'd started back then."
        return VStack(spacing: 18) {
            Text(label).font(.system(size: 44, weight: .heavy)).foregroundStyle(Theme.acc)
                .frame(maxWidth: .infinity).contentTransition(.numericText())
                .animation(.snappy, value: Int(yrs))
            Slider(value: $data.timeWantedYears, in: 0...15, step: 1).tint(Theme.acc)
                .sensoryFeedback(.selection, trigger: Int(yrs))
            Text(gut).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.mut)
                .multilineTextAlignment(.center).animation(.easeInOut, value: gut)
        }
        .padding(.top, 24)
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
        case .motivation: return true   // optional
        case .timeWanted: return true
        case .resultsFeeling: return data.resultsFeeling != nil
        case .triedPlan: return data.triedPlan != nil
        case .sex: return data.sex != nil
        case .pace: return data.pace != nil
        case .activity: return data.activity != nil
        case .goal: return data.goal != nil
        case .obstacles: return true   // optional
        case .experience: return data.experience != nil
        case .currentSplit: return true   // optional
        case .days: return data.daysPerWeek != nil
        case .equipment: return data.equipment != nil
        case .height, .weight, .goalWeight, .age: return true
        case .equipmentDetail: return true   // optional
        case .attribution: return data.attribution != nil
        case .reminders: return true   // tap-to-finish
        default: return true   // interstitials
        }
    }

    // Skip equipment-detail unless they train at home / dumbbells-only.
    private func shouldShow(_ s: OnbStep) -> Bool {
        switch s {
        case .equipmentDetail: return data.equipment == "home"
        case .currentSplit: return data.experience != nil && data.experience != "beginner"
        default: return true
        }
    }
    private func nextIndex(after i: Int) -> Int {
        var n = i + 1
        while n < total - 1 && !shouldShow(OnbStep.allCases[n]) { n += 1 }
        return n
    }
    private func prevIndex(before i: Int) -> Int {
        var n = i - 1
        while n > 0 && !shouldShow(OnbStep.allCases[n]) { n -= 1 }
        return n
    }

    private func back() {
        unit = 0
        if stepIndex > 0 { withAnimation { stepIndex = prevIndex(before: stepIndex) } }
    }
    private func advance() {
        unit = 0
        error = nil
        UserDefaults.standard.set(data.daysPerWeek ?? 4, forKey: "steticDays")
        if stepIndex < total - 1 {
            let next = nextIndex(after: stepIndex)
            // Seed the goal-weight slider from current weight the first time we land on it.
            if OnbStep.allCases[next] == .goalWeight && !seededGoalWeight {
                data.goalWeightKg = data.weightKg; seededGoalWeight = true
            }
            withAnimation { stepIndex = next }; return
        }
        // last step → hand the answers up; they're persisted after sign-in (right before the paywall)
        onComplete(data)
    }
}

#Preview { OnboardingView(onComplete: { _ in }).preferredColorScheme(.dark) }
