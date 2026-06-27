import SwiftUI

// The post-scan app: Today (streak + session), Plan, Food, Profile.
struct MainTabView: View {
    var name: String = ""
    @State private var bundle: ScanAPI.PlanBundle?
    @State private var workoutDates: [String] = []
    @State private var showScan = false
    @State private var tab = Int(ProcessInfo.processInfo.environment["STETIC_TAB"] ?? "") ?? 0
    @Environment(\.requestReview) private var requestReview
    @AppStorage("askedReview") private var askedReview = false
    @AppStorage("askedWorkoutTime") private var askedWorkoutTime = false
    @State private var showWorkoutTime = false

    init(name: String = "") {
        self.name = name
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(Theme.bg)
        a.shadowColor = UIColor(Theme.line)
        UITabBar.appearance().standardAppearance = a
        UITabBar.appearance().scrollEdgeAppearance = a
    }

    var body: some View {
        TabView(selection: $tab) {
            HomeView(name: name, bundle: bundle, workoutDates: workoutDates,
                     goFood: { tab = 2 }, refresh: { await refresh() })
                .tabItem { Label("Today", systemImage: "bolt.heart.fill") }.tag(0)
            PlanView(showsClose: false, onRescan: { showScan = true })
                .tabItem { Label("Plan", systemImage: "list.bullet.rectangle.portrait.fill") }.tag(1)
            NutritionView(target: bundle?.content.macros)
                .tabItem { Label("Food", systemImage: "fork.knife") }.tag(2)
            ProgressScreen(scan: bundle?.scan, name: name, onNewScan: { showScan = true })
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }.tag(3)
        }
        .tint(Theme.acc)
        .task {
            await refresh()
            if !askedWorkoutTime, bundle != nil {
                await MainActor.run { showWorkoutTime = true }   // first entry: ask their workout time
            } else if !askedReview, askedWorkoutTime, bundle != nil {
                try? await Task.sleep(nanoseconds: 2_000_000_000)   // a later session: ask for a rating
                await MainActor.run { requestReview(); askedReview = true }
            }
        }
        .fullScreenCover(isPresented: $showWorkoutTime) {
            WorkoutTimeSheet(daysPerWeek: bundle?.content.weekly_split.count ?? 4,
                             onDone: { askedWorkoutTime = true })
        }
        .fullScreenCover(isPresented: $showScan) {
            RevealFunnelView(name: name, rescan: true, onFinish: {
                showScan = false
                bundle = nil   // a re-scan produces a new plan — drop the cached one
                Task { await refresh() }
            })
        }
    }

    private func refresh() async {
        // Load the streak immediately; the plan (slow Gemini call) loads in parallel.
        async let dates = ScanAPI.shared.workoutDates()
        workoutDates = (try? await dates) ?? []
        if bundle == nil { bundle = try? await ScanAPI.shared.plan() }
    }
}

// MARK: - Today
struct HomeView: View {
    let name: String
    let bundle: ScanAPI.PlanBundle?
    let workoutDates: [String]
    let goFood: () -> Void
    let refresh: () async -> Void

    @State private var session: PlanContent.Day?
    @State private var meals: [MealLog] = []
    @State private var showCheckIn = false
    @State private var checkIns: [CheckIn] = []
    @State private var showStreakInfo = false
    @AppStorage("healthConnected") private var healthConnected = false
    @State private var steps = 0
    @State private var showSchedule = false
    @State private var showStepGoal = false
    @State private var streakFlare = false
    @AppStorage("trainWeekdays") private var trainWeekdaysRaw = ""   // e.g. "2,4,6"
    @AppStorage("trainHour") private var trainHour = 17
    @AppStorage("deloadAnchor") private var deloadAnchor = ""        // yyyy-MM-dd
    @AppStorage("stepGoal") private var stepGoal = 10000      // JP: ~10k/day for health
    @AppStorage("stepStreakOn") private var stepStreakOn = false     // step goal keeps streak alive on rest days
    @AppStorage("activityDates") private var activityCSV = ""        // days the step goal was met

    // Only real training days are in the rotation — never "rest"/"recovery" entries.
    private var split: [PlanContent.Day] {
        (bundle?.content.weekly_split ?? []).filter {
            let s = ($0.day + " " + $0.focus).lowercased()
            return !s.contains("rest") && !s.contains("recovery") && !$0.exercises.isEmpty
        }
    }
    private var checkedInToday: Bool { checkIns.contains { $0.log_date == LogDate.today } }
    private var todayCheckIn: CheckIn? { checkIns.first { $0.log_date == LogDate.today } }
    private var checkInSummaryCard: some View {
        let quote = Quotes.forReadiness(todayCheckIn?.readiness ?? 3)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundStyle(Theme.acc)
                Text("CHECKED IN TODAY").font(.system(size: 10.5, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
            }
            Text(quote.text).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: 0xD2D2D8)).lineSpacing(3)
            Text("— \(quote.who)").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
    }
    private var isTrainingDay: Bool {
        let wd = Calendar.current.component(.weekday, from: AppClock.now)
        return trainingDays.contains(wd)
    }
    private var checkInCard: some View {
        Button { showCheckIn = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").font(.system(size: 18)).foregroundStyle(Theme.acc)
                    .frame(width: 42, height: 42).background(Circle().fill(Theme.acc.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("How are you feeling today?").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.txt)
                    Text("10-second check-in — we'll tailor your day").font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.acc.opacity(0.3), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private var activityDates: [String] { activityCSV.split(separator: ",").map(String.init) }
    // Streak counts training days, plus step-goal days when the user opts in.
    private var streak: Int { Streak.count(from: workoutDates + (stepStreakOn ? activityDates : [])) }
    private var loggedToday: Bool { workoutDates.contains(LogDate.today) }
    // Real users get one session per day; dev builds can re-log to test.
    private var canRelogToday: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    private var upNext: PlanContent.Day? {
        guard !split.isEmpty else { return nil }
        let i = (workoutDates.count) % split.count
        return split[i]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(greeting).font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.txt)
                if !checkedInToday { checkInCard }
                weekStrip
                if deloadDue { deloadBanner }
                HStack(spacing: 12) { streakCard; stepsCard }
                upNextCard
                fuelCard
                if checkedInToday { checkInSummaryCard }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
        }
        .background(Theme.bg.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .task {
            meals = (try? await ScanAPI.shared.meals(on: LogDate.today)) ?? []
            checkIns = (try? await ScanAPI.shared.recentCheckIns()) ?? []
            if healthConnected { steps = await HealthKitManager.shared.todaySteps(); recordStepDay() }
        }
        .sheet(isPresented: $showStepGoal) { StepGoalSheet() }
        .sheet(isPresented: $showStreakInfo) { StreakInfoSheet(streak: streak, graceActive: graceActive) }
        .sheet(isPresented: $showCheckIn, onDismiss: { Task { checkIns = (try? await ScanAPI.shared.recentCheckIns()) ?? [] } }) {
            CheckInView(trainingDay: isTrainingDay, history: checkIns, workoutDates: workoutDates,
                        onStartSession: { if let d = upNext { session = d } }, onDone: {})
        }
        .sheet(item: $session) { day in
            SessionLogView(day: day) {
                Task {
                    await refresh()
                    meals = (try? await ScanAPI.shared.meals(on: LogDate.today)) ?? []
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { streakFlare = true }
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    withAnimation(.easeOut(duration: 0.4)) { streakFlare = false }
                }
            }
        }
        .sheet(isPresented: $showSchedule) {
            ScheduleSheet(weekdays: trainingDays, hour: trainHour, requiredDays: split.count) { days, hour in
                trainWeekdaysRaw = days.sorted().map(String.init).joined(separator: ",")
                trainHour = hour
                NotificationManager.setTrainingReminders(weekdays: days, hour: hour)
            }
        }
    }

    // MARK: week strip — which days you train, what you've done, what's next
    // Training weekdays: the user's saved choice, else a sensible spread from the split size.
    private var trainingDays: Set<Int> {
        let saved = Set(trainWeekdaysRaw.split(separator: ",").compactMap { Int($0) })
        if !saved.isEmpty { return saved }
        return Self.defaultWeekdays(forTrainingDays: max(1, split.count))
    }
    static func defaultWeekdays(forTrainingDays n: Int) -> Set<Int> {
        switch min(7, max(1, n)) {       // weekday: 1=Sun … 7=Sat
        case 1: return [2]; case 2: return [2, 5]; case 3: return [2, 4, 6]
        case 4: return [2, 3, 5, 6]; case 5: return [2, 3, 4, 5, 6]
        case 6: return [2, 3, 4, 5, 6, 7]; default: return [1, 2, 3, 4, 5, 6, 7]
        }
    }
    private var weekDates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: AppClock.now)
        guard let start = cal.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("THIS WEEK").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
                Spacer()
                Button { showSchedule = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.system(size: 10, weight: .bold))
                        Text("\(trainingDays.count)× · \(hourLabel(trainHour))").font(.system(size: 11, weight: .semibold))
                    }.foregroundStyle(Theme.acc)
                }
            }
            HStack(spacing: 6) {
                ForEach(weekDates, id: \.self) { d in dayChip(d) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
    }

    private func dayChip(_ date: Date) -> some View {
        let cal = Calendar.current
        let wd = cal.component(.weekday, from: date)
        let isToday = cal.isDate(date, inSameDayAs: AppClock.now)
        let isPast = date < cal.startOfDay(for: AppClock.now)
        let logged = workoutDates.contains(LogDate.string(date))
        let train = trainingDays.contains(wd)
        let letters = ["", "S", "M", "T", "W", "T", "F", "S"]
        return VStack(spacing: 6) {
            Text(letters[wd]).font(.system(size: 11, weight: .bold)).foregroundStyle(isToday ? Theme.acc : Theme.mut)
            ZStack {
                Circle().fill(logged ? Theme.acc : Color.clear)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(chipStroke(train: train, logged: logged, isToday: isToday, isPast: isPast), lineWidth: isToday ? 2 : 1))
                if logged {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: 0x0E0E10))
                } else if train && isPast {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.mut)
                } else if train {
                    Circle().fill(Theme.acc).frame(width: 6, height: 6)
                }
            }
            Text("\(cal.component(.day, from: date))").font(.system(size: 10, weight: .semibold)).foregroundStyle(isToday ? Theme.txt : Theme.mut)
        }
        .frame(maxWidth: .infinity)
    }
    private func chipStroke(train: Bool, logged: Bool, isToday: Bool, isPast: Bool) -> Color {
        if logged { return .clear }
        if isToday { return Theme.acc }
        if train { return Theme.acc.opacity(0.5) }
        return Theme.line
    }
    private func hourLabel(_ h: Int) -> String {
        let ampm = h < 12 ? "am" : "pm"; let hr = h % 12 == 0 ? 12 : h % 12
        return "\(hr)\(ampm)"
    }

    // MARK: deload — JP doctrine: pull back every ~8 weeks
    private var weeksTraining: Int {
        let cal = Calendar.current
        let anchorStr = deloadAnchor.isEmpty ? (workoutDates.last ?? "") : deloadAnchor
        guard let start = LogDate.fmt.date(from: anchorStr) else { return 0 }
        return (cal.dateComponents([.day], from: start, to: AppClock.now).day ?? 0) / 7
    }
    private var deloadDue: Bool { weeksTraining >= 8 }
    private var deloadBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wind").font(.system(size: 18)).foregroundStyle(Theme.amber)
                .frame(width: 42, height: 42).background(Circle().fill(Theme.amber.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Deload week").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.txt)
                Text("\(weeksTraining) weeks in — keep your weights, but stop ~2 reps short of failure (3–4 on the 15–20 sets). Or take the whole week off. Recover, then go again.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.mut).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button { deloadAnchor = LogDate.today } label: {
                Text("Done").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.amber)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x1E1A12))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.amber.opacity(0.25), lineWidth: 1)))
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 12 ? "Good morning" : (h < 18 ? "Good afternoon" : "Good evening")
        return name.isEmpty ? part : "\(part), \(name)"
    }

    private var graceActive: Bool { Streak.graceActive(from: workoutDates + (stepStreakOn ? activityDates : [])) }
    private var streakCard: some View {
        Button { showStreakInfo = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle().fill(Color(hex: 0xFF7A1A).opacity(streakFlare ? 0.28 : 0.14)).frame(width: 50, height: 50)
                    FireFlame(size: 24, flare: streakFlare)
                }
                .scaleEffect(streakFlare ? 1.15 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streak) day\(streak == 1 ? "" : "s")").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.txt)
                    Text(streak == 0 ? "Start your streak" : (graceActive ? "Grace day — act to keep it" : "Day streak"))
                        .font(.system(size: 11, weight: graceActive ? .bold : .regular))
                        .foregroundStyle(graceActive ? Theme.amber : Theme.mut)
                }
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(graceActive ? Theme.amber.opacity(0.4) : .clear, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private var stepsCard: some View {
        Button {
            if healthConnected { showStepGoal = true }
            else { Task { await HealthKitManager.shared.requestAuth(); healthConnected = true
                steps = await HealthKitManager.shared.todaySteps(); recordStepDay() } }
        } label: {
            let progress = (stepStreakOn && stepGoal > 0) ? min(1, Double(steps) / Double(stepGoal)) : 0
            let met = stepStreakOn && stepGoal > 0 && steps >= stepGoal
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    if stepStreakOn && stepGoal > 0 {
                        Circle().stroke(Theme.line, lineWidth: 4).frame(width: 50, height: 50)
                        Circle().trim(from: 0, to: progress)
                            .stroke(Theme.acc, style: .init(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90)).frame(width: 50, height: 50)
                            .animation(.easeOut(duration: 0.5), value: progress)
                    } else {
                        Circle().fill(Theme.acc.opacity(0.14)).frame(width: 50, height: 50)
                    }
                    Image(systemName: met ? "checkmark" : "figure.walk")
                        .font(.system(size: met ? 20 : 22, weight: met ? .heavy : .regular)).foregroundStyle(Theme.acc)
                }
                .scaleEffect(met && streakFlare ? 1.15 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    if healthConnected {
                        Text(steps.formatted()).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.txt)
                        Text(met ? "Goal hit — streak safe" : (stepStreakOn ? "of \(stepGoal.formatted()) steps" : "Steps today"))
                            .font(.system(size: 11, weight: met ? .bold : .regular)).foregroundStyle(met ? Theme.acc : Theme.mut)
                    } else {
                        Text("Steps").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.txt)
                        Text("Connect Health").font(.system(size: 11)).foregroundStyle(Theme.acc)
                    }
                }
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
        }
        .buttonStyle(.plain)
    }

    private func recordStepDay() {
        guard stepStreakOn, stepGoal > 0, steps >= stepGoal else { return }
        var days = activityDates
        guard !days.contains(LogDate.today) else { return }
        days.append(LogDate.today); activityCSV = days.joined(separator: ",")
        // Steps just kept the streak alive today — flare the flame to show it.
        Task { @MainActor in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { streakFlare = true }
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeOut(duration: 0.4)) { streakFlare = false }
        }
    }

    @ViewBuilder private var upNextCard: some View {
        if let day = upNext {
            let isRest = !isTrainingDay && !loggedToday
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(isRest ? "REST DAY" : (loggedToday ? "DONE TODAY" : "UP NEXT")).font(.system(size: 11, weight: .bold)).tracking(1)
                        .foregroundStyle(loggedToday || isRest ? Theme.acc : Theme.mut)
                    Spacer()
                    if loggedToday { Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.acc) }
                    else if isRest { Image(systemName: "moon.zzz.fill").foregroundStyle(Theme.acc) }
                }
                if isRest {
                    Text("Rest day").font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.txt)
                    Text("Muscle grows when you recover. Hit your steps — and only train if you feel like it.")
                        .font(.system(size: 13)).foregroundStyle(Theme.mut).lineSpacing(2)
                    Text("Next up: \(day.day)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
                } else {
                    Text(day.day).font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.txt)
                    Text(day.focus).font(.system(size: 13)).foregroundStyle(Theme.mut)
                    HStack(spacing: 6) {
                        Image(systemName: "dumbbell.fill").font(.system(size: 11)).foregroundStyle(Theme.acc)
                        Text("\(day.exercises.count) exercises").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt)
                    }
                }
                if isRest {
                    Button { session = day } label: {
                        Text("Train anyway").font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1)))
                            .foregroundStyle(Theme.txt)
                    }
                    .padding(.top, 2)
                } else if loggedToday && !canRelogToday {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 13)).foregroundStyle(Theme.acc)
                        Text("Trained today — rest up and come back tomorrow")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut)
                    }
                    .frame(maxWidth: .infinity).padding(13)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1)))
                    .padding(.top, 2)
                } else {
                    Button { session = day } label: {
                        Text(loggedToday ? "Log another session (dev)" : "Start session")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity).padding(13)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.acc))
                            .foregroundStyle(Color(hex: 0x0E0E10))
                    }
                    .padding(.top, 2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.acc.opacity(0.25), lineWidth: 1)))
        }
    }

    private var fuelCard: some View {
        let target = bundle?.content.macros
        let cals = meals.reduce(0) { $0 + $1.calories }
        let protein = meals.reduce(0) { $0 + $1.protein_g }
        return Button(action: goFood) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("TODAY'S FUEL").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(cals))").font(.system(size: 24, weight: .heavy)).foregroundStyle(Theme.txt)
                    if let t = target { Text("/ \(Int(t.calories)) cal").font(.system(size: 13)).foregroundStyle(Theme.mut) }
                }
                if let t = target {
                    ProgressBar(value: cals, total: t.calories, tint: Theme.acc)
                    Text("\(Int(protein))g / \(Int(t.protein_g))g protein").font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
        }
        .buttonStyle(.plain)
    }
}

// Pick training weekdays + a reminder time. Drives the week strip and notifications.
struct ScheduleSheet: View {
    @State var weekdays: Set<Int>
    @State var hour: Int
    var requiredDays: Int = 0          // plan's training-day count; 0 = unconstrained
    var onSave: (Set<Int>, Int) -> Void
    @Environment(\.dismiss) private var dismiss

    private let labels = [(1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")]
    private var countOK: Bool { requiredDays == 0 || weekdays.count == requiredDays }

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Theme.line).frame(width: 38, height: 5).padding(.top, 10)
            Text("Training schedule").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
            if requiredDays > 0 {
                Text(weekdays.count == requiredDays
                     ? "Pick the \(requiredDays) days that fit your week."
                     : "Your plan is \(requiredDays) days — pick \(requiredDays) (\(weekdays.count) selected).")
                    .font(.system(size: 12)).foregroundStyle(countOK ? Theme.mut : Theme.amber)
                    .multilineTextAlignment(.center)
            } else {
                Text("Which days do you train?").font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            HStack(spacing: 8) {
                ForEach(labels, id: \.0) { wd, letter in
                    let on = weekdays.contains(wd)
                    Button {
                        if on { weekdays.remove(wd) }
                        else {
                            // Honor the plan's day count: drop the oldest pick when full.
                            if requiredDays > 0 && weekdays.count >= requiredDays {
                                if let drop = weekdays.sorted().first { weekdays.remove(drop) }
                            }
                            weekdays.insert(wd)
                        }
                    } label: {
                        Text(letter).font(.system(size: 15, weight: .bold))
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(on ? Theme.acc : Theme.card)
                                .overlay(Circle().stroke(on ? .clear : Theme.line, lineWidth: 1)))
                            .foregroundStyle(on ? Color(hex: 0x0E0E10) : Theme.txt)
                    }
                }
            }
            DatePicker("Reminder time",
                       selection: Binding(
                        get: { Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date() },
                        set: { hour = Calendar.current.component(.hour, from: $0) }),
                       displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact).labelsHidden().padding(.top, 4)
                .colorScheme(.dark)
            Button {
                onSave(weekdays, hour); dismiss()
            } label: {
                Text("Save").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(countOK && !weekdays.isEmpty ? Theme.acc : Theme.line))
                    .foregroundStyle(countOK && !weekdays.isEmpty ? Color(hex: 0x0E0E10) : Theme.mut)
            }
            .disabled(weekdays.isEmpty || !countOK)
            Spacer()
        }
        .padding(.horizontal, 22)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.height(330)])
    }
}

// Explains how the streak works: one grace day, never miss twice, no compensating.
struct StreakInfoSheet: View {
    let streak: Int
    let graceActive: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Theme.line).frame(width: 38, height: 5).padding(.top, 10)
            ZStack {
                Circle().fill(Color(hex: 0xFF7A1A).opacity(0.16)).frame(width: 72, height: 72)
                FireFlame(size: 36, flare: true)
            }
            Text("\(streak)-day streak").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.txt)
            if graceActive {
                Text("You missed yesterday — that's your one grace day. Train (or hit your steps) today to keep it.")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.amber)
                    .multilineTextAlignment(.center).padding(.horizontal, 10)
            }
            VStack(alignment: .leading, spacing: 12) {
                rule("calendar", "One missed day is fine.", "Miss once and your streak lives. Miss twice in a row and it resets — \u{201C}never miss twice\u{201D} (James Clear).")
                rule("scalemass", "Don't compensate.", "Overate yesterday? Don't crash-diet today. Under-ate? Don't binge. Just hit today's plan — consistency beats correction.")
                rule("flame.fill", "Steps can save a rest day.", "Turn on the step goal and hitting it keeps the streak alive on days you don't train.")
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
            Button { dismiss() } label: {
                Text("Got it").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.acc)).foregroundStyle(Color(hex: 0x0E0E10))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.height(480)])
    }
    private func rule(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Theme.acc).frame(width: 22).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                Text(body).font(.system(size: 12)).foregroundStyle(Theme.mut).lineSpacing(2)
            }
        }
    }
}

// Set a daily step goal and opt in to step-goal days keeping the streak alive.
struct StepGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("stepGoal") private var goal = 8000
    @AppStorage("stepStreakOn") private var streakOn = false

    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Theme.line).frame(width: 38, height: 5).padding(.top, 10)
            Text("Daily steps").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
            Text("Set a step goal to keep your streak alive on rest days.")
                .font(.system(size: 12)).foregroundStyle(Theme.mut).multilineTextAlignment(.center).padding(.horizontal, 20)
            HStack(spacing: 22) {
                stepButton("minus") { goal = max(2000, goal - 500) }
                VStack(spacing: 0) {
                    Text(goal.formatted()).font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.txt)
                    Text("steps / day").font(.system(size: 11)).foregroundStyle(Theme.mut)
                }.frame(minWidth: 120)
                stepButton("plus") { goal = min(25000, goal + 500) }
            }
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $streakOn) {
                    Text("Hold me to my steps on rest days").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                }.tint(Theme.acc)
                Text(streakOn
                     ? "Tougher mode: on a non-training day you MUST hit your steps or your streak is at risk. (You still get one grace day — never miss twice.)"
                     : "Off: rest days never put your streak at risk.")
                    .font(.system(size: 11)).foregroundStyle(streakOn ? Theme.amber : Theme.mut).lineSpacing(2)
            }
            .padding(.horizontal, 4)
            Button { dismiss() } label: {
                Text("Done").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.acc)).foregroundStyle(Color(hex: 0x0E0E10))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.height(330)])
    }
    private func stepButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                .frame(width: 44, height: 44).background(Circle().fill(Theme.card).overlay(Circle().stroke(Theme.line, lineWidth: 1)))
        }
    }
}

// Thin progress bar used across the app.
struct ProgressBar: View {
    let value: Double; let total: Double; var tint: Color = Theme.acc
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule().fill(tint)
                    .frame(width: max(0, min(1, total <= 0 ? 0 : value / total)) * geo.size.width)
            }
        }
        .frame(height: 7)
    }
}
