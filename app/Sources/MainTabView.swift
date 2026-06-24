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
            PlanView(showsClose: false)
                .tabItem { Label("Plan", systemImage: "list.bullet.rectangle.portrait.fill") }.tag(1)
            NutritionView(target: bundle?.content.macros)
                .tabItem { Label("Food", systemImage: "fork.knife") }.tag(2)
            ProfileView(scan: bundle?.scan, onNewScan: { showScan = true })
                .tabItem { Label("Profile", systemImage: "person.fill") }.tag(3)
        }
        .tint(Theme.acc)
        .task { await refresh() }
        .fullScreenCover(isPresented: $showScan) {
            RevealFunnelView(name: name, onFinish: { showScan = false; Task { await refresh() } })
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

    private var split: [PlanContent.Day] { bundle?.content.weekly_split ?? [] }
    private var streak: Int { Streak.count(from: workoutDates) }
    private var loggedToday: Bool { workoutDates.contains(LogDate.today) }
    private var upNext: PlanContent.Day? {
        guard !split.isEmpty else { return nil }
        let i = (workoutDates.count) % split.count
        return split[i]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(greeting).font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.txt)
                streakCard
                upNextCard
                fuelCard
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
        }
        .background(Theme.bg.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .task { meals = (try? await ScanAPI.shared.meals(on: LogDate.today)) ?? [] }
        .sheet(item: $session) { day in
            SessionLogView(day: day) { Task { await refresh(); meals = (try? await ScanAPI.shared.meals(on: LogDate.today)) ?? [] } }
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 12 ? "Good morning" : (h < 18 ? "Good afternoon" : "Good evening")
        return name.isEmpty ? part : "\(part), \(name)"
    }

    private var streakCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.acc.opacity(0.14)).frame(width: 64, height: 64)
                Image(systemName: "flame.fill").font(.system(size: 28)).foregroundStyle(Theme.acc)
            }
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
                Button { session = day } label: {
                    Text(loggedToday ? "Log another session" : "Start session")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity).padding(13)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.acc))
                        .foregroundStyle(Color(hex: 0x0E0E10))
                }
                .padding(.top, 2)
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

// MARK: - Profile
struct ProfileView: View {
    let scan: ScoreCard?
    let onNewScan: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Profile").font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.txt)
                if let scan {
                    HStack(spacing: 14) {
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", scan.aesthetic_score)).font(.system(size: 26, weight: .heavy)).foregroundStyle(scan.tier.color)
                            Text(scan.tier.label).font(.system(size: 11, weight: .bold)).foregroundStyle(scan.tier.color)
                        }
                        Divider().frame(height: 38).overlay(Theme.line)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Latest scan").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                            Text("Re-scan to track your ascension").font(.system(size: 11)).foregroundStyle(Theme.mut)
                        }
                        Spacer()
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                }
                Button(action: onNewScan) {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder").font(.system(size: 16, weight: .bold))
                        Text("New scan").font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 13).fill(Theme.acc))
                    .foregroundStyle(Color(hex: 0x0E0E10))
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
        }
        .background(Theme.bg.ignoresSafeArea())
        .scrollIndicators(.hidden)
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
