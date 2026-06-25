import SwiftUI

// The post-scan app: Today (streak + session), Plan, Food, Profile.
struct MainTabView: View {
    var name: String = ""
    @State private var bundle: ScanAPI.PlanBundle?
    @State private var workoutDates: [String] = []
    @State private var showScan = false
    @State private var tab = Int(ProcessInfo.processInfo.environment["STETIC_TAB"] ?? "") ?? 0

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
        .task { await refresh() }
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
    @AppStorage("healthConnected") private var healthConnected = false
    @State private var steps = 0
    @State private var showSchedule = false
    @State private var streakFlare = false
    @AppStorage("trainWeekdays") private var trainWeekdaysRaw = ""   // e.g. "2,4,6"
    @AppStorage("trainHour") private var trainHour = 17
    @AppStorage("deloadAnchor") private var deloadAnchor = ""        // yyyy-MM-dd

    // Only real training days are in the rotation — never "rest"/"recovery" entries.
    private var split: [PlanContent.Day] {
        (bundle?.content.weekly_split ?? []).filter {
            let s = ($0.day + " " + $0.focus).lowercased()
            return !s.contains("rest") && !s.contains("recovery") && !$0.exercises.isEmpty
        }
    }
    private var streak: Int { Streak.count(from: workoutDates) }
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
                weekStrip
                if deloadDue { deloadBanner }
                streakCard
                healthCard
                upNextCard
                fuelCard
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
        }
        .background(Theme.bg.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .task {
            meals = (try? await ScanAPI.shared.meals(on: LogDate.today)) ?? []
            if healthConnected { steps = await HealthKitManager.shared.todaySteps() }
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
        let today = cal.startOfDay(for: Date())
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
        let isToday = cal.isDateInToday(date)
        let isPast = date < cal.startOfDay(for: Date())
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
        return (cal.dateComponents([.day], from: start, to: Date()).day ?? 0) / 7
    }
    private var deloadDue: Bool { weeksTraining >= 8 }
    private var deloadBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wind").font(.system(size: 18)).foregroundStyle(Theme.amber)
                .frame(width: 42, height: 42).background(Circle().fill(Theme.amber.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Deload week").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.txt)
                Text("\(weeksTraining) weeks in — drop to ~60% volume this week so you keep growing.")
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

    @ViewBuilder private var healthCard: some View {
        if healthConnected {
            HStack(spacing: 14) {
                Image(systemName: "figure.walk").font(.system(size: 20)).foregroundStyle(Theme.acc)
                    .frame(width: 44, height: 44).background(Circle().fill(Theme.acc.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(steps.formatted()) steps").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
                    Text("Today · from Apple Health").font(.system(size: 11)).foregroundStyle(Theme.mut)
                }
                Spacer()
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
        } else {
            Button {
                Task {
                    await HealthKitManager.shared.requestAuth()
                    healthConnected = true
                    steps = await HealthKitManager.shared.todaySteps()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill").font(.system(size: 16)).foregroundStyle(Color(hex: 0xFF6B6B))
                    Text("Connect Apple Health").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1)))
            }
            .buttonStyle(.plain)
        }
    }

    private var streakCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color(hex: 0xFF7A1A).opacity(streakFlare ? 0.28 : 0.14)).frame(width: 64, height: 64)
                FireFlame(size: 30, flare: streakFlare)
            }
            .scaleEffect(streakFlare ? 1.18 : 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(streak) day\(streak == 1 ? "" : "s")").font(.system(size: 24, weight: .heavy)).foregroundStyle(Theme.txt)
                Text(streak == 0 ? "Log a session to start your streak" : "Training streak — keep it alive")
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
    }

    @ViewBuilder private var upNextCard: some View {
        if let day = upNext {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(loggedToday ? "DONE TODAY" : "UP NEXT").font(.system(size: 11, weight: .bold)).tracking(1)
                        .foregroundStyle(loggedToday ? Theme.acc : Theme.mut)
                    Spacer()
                    if loggedToday { Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.acc) }
                }
                Text(day.day).font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.txt)
                Text(day.focus).font(.system(size: 13)).foregroundStyle(Theme.mut)
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill").font(.system(size: 11)).foregroundStyle(Theme.acc)
                    Text("\(day.exercises.count) exercises").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt)
                }
                if loggedToday && !canRelogToday {
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
