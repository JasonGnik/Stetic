import Foundation

enum APIError: LocalizedError {
    case http(Int, String)
    case decode
    case noSession

    var errorDescription: String? {
        switch self {
        case .http(let code, let msg): return "Server error \(code): \(msg)"
        case .decode: return "Could not read the response."
        case .noSession: return "Not signed in."
        }
    }
}

// Talks to the Supabase auth + edge functions. Dev auth for now (email/password);
// swap for Apple Sign In later. Holds the access token in-memory.
actor ScanAPI {
    static let shared = ScanAPI()

    private var accessToken: String?
    private var userId: String?

    struct ImageInput { let mimeType: String; let dataB64: String }
    struct ProfileInput: Sendable {
        var sex: String?; var goal: String?; var motivation: [String] = []; var focus: [String]
        var experience: String?; var currentSplit: String?
        var daysPerWeek: Int?; var equipment: String?
        var heightCm: Double; var weightKg: Double; var age: Int
        var goalWeightKg: Double?
        var activity: String?; var pace: String?
        var attribution: String?
    }

    private var refreshToken: String?
    private let refreshKey = "stetic.refreshToken"

    func currentUserID() -> String? { userId }
    var isSignedIn: Bool { accessToken != nil }

    // MARK: auth (dev) — sign in, or sign up then sign in.
    func ensureSession() async throws {
        if accessToken != nil { return }
        if let tok = try? await signIn() { accessToken = tok; return }
        try await signUp()
        accessToken = try await signIn()
    }

    // MARK: Apple Sign In — exchange the Apple identity token for a Supabase session.
    func signInWithApple(idToken: String, nonce: String) async throws {
        let url = Config.baseURL.appending(path: "auth/v1/token")
            .appending(queryItems: [.init(name: "grant_type", value: "id_token")])
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "provider": "apple", "id_token": idToken, "nonce": nonce,
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        try storeSession(data, code(resp))
    }

    // Email/password sign-in.
    func signInEmail(_ email: String, _ password: String) async throws {
        let url = Config.baseURL.appending(path: "auth/v1/token").appending(queryItems: [.init(name: "grant_type", value: "password")])
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let (data, resp) = try await URLSession.shared.data(for: req)
        try storeSession(data, code(resp))
    }

    // Email/password sign-up. Returns true if a session was created, false if the
    // project requires email confirmation first.
    @discardableResult
    func signUpEmail(_ email: String, _ password: String) async throws -> Bool {
        let url = Config.baseURL.appending(path: "auth/v1/signup")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = code(resp)
        guard status == 200 || status == 201 else { throw APIError.http(status, String(data: data, encoding: .utf8) ?? "") }
        return (try? storeSession(data, status)) != nil   // no token → confirmation required
    }

    // OAuth (Google): bootstrap a full session from the refresh token in the callback.
    func applyOAuthRefresh(_ refreshToken: String) async -> Bool {
        accessToken = nil
        UserDefaults.standard.set(refreshToken, forKey: refreshKey)
        return await restoreSession()
    }

    // Restore a saved session on launch (refresh-token grant). Returns true if signed in.
    func restoreSession() async -> Bool {
        if accessToken != nil { return true }
        guard let rt = UserDefaults.standard.string(forKey: refreshKey) else { return false }
        let url = Config.baseURL.appending(path: "auth/v1/token")
            .appending(queryItems: [.init(name: "grant_type", value: "refresh_token")])
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": rt])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (try? storeSession(data, code(resp))) != nil else {
            UserDefaults.standard.removeObject(forKey: refreshKey); return false
        }
        return true
    }

    func signOut() {
        accessToken = nil; userId = nil; refreshToken = nil
        UserDefaults.standard.removeObject(forKey: refreshKey)
        clearPlanCache()
    }

    // Permanently delete the account + all data (App Store 5.1.1(v)), then sign out.
    func deleteAccount() async throws {
        try await ensureSession()
        guard let token = accessToken else { throw APIError.noSession }
        let url = Config.baseURL.appending(path: "functions/v1/delete-account")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = code(resp)
        guard status == 200 else { throw APIError.http(status, String(data: data, encoding: .utf8) ?? "") }
        signOut()
    }

    private func storeSession(_ data: Data, _ status: Int) throws {
        guard status == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = obj["access_token"] as? String
        else { throw APIError.http(status, String(data: data, encoding: .utf8) ?? "") }
        accessToken = token
        userId = (obj["user"] as? [String: Any])?["id"] as? String
        if let rt = obj["refresh_token"] as? String {
            refreshToken = rt
            UserDefaults.standard.set(rt, forKey: refreshKey)
        }
    }

    private func signIn() async throws -> String {
        let url = Config.baseURL.appending(path: "auth/v1/token").appending(queryItems: [
            .init(name: "grant_type", value: "password")
        ])
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": Config.devEmail, "password": Config.devPassword,
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = obj["access_token"] as? String
        else { throw APIError.http(code(resp), String(data: data, encoding: .utf8) ?? "") }
        userId = (obj["user"] as? [String: Any])?["id"] as? String
        return token
    }

    // MARK: profile
    func saveProfile(_ p: ProfileInput) async throws {
        try await ensureSession()
        guard let token = accessToken, let uid = userId else { throw APIError.noSession }
        var comps = URLComponents(
            url: Config.baseURL.appending(path: "rest/v1/profiles"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "id", value: "eq.\(uid)")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "PATCH"
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        var body: [String: Any] = [
            "focus": p.focus, "height_cm": p.heightCm, "weight_kg": p.weightKg, "age": p.age,
        ]
        if !p.motivation.isEmpty { body["motivation"] = p.motivation }   // column may not be deployed yet
        if let v = p.sex { body["sex"] = v }
        if let v = p.goal { body["goal"] = v }
        if let v = p.experience { body["experience"] = v }
        if let v = p.currentSplit, !v.isEmpty { body["current_split"] = v }
        if let v = p.daysPerWeek { body["days_per_week"] = v }
        if let v = p.equipment { body["equipment"] = v }
        if let v = p.goalWeightKg { body["goal_weight_kg"] = v }
        if let v = p.activity { body["activity_level"] = v }
        if let v = p.pace { body["pace"] = v }
        if let v = p.attribution { body["attribution"] = v }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let s = code(resp)
        guard s == 204 || s == 200 else { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
    }

    // Update just the plan-driving inputs (used when regenerating a plan with fresh answers).
    func updatePlanInputs(goal: String, daysPerWeek: Int, pace: String, weightKg: Double, goalWeightKg: Double) async throws {
        try await ensureSession()
        guard let uid = userId else { throw APIError.noSession }
        let body = try JSONSerialization.data(withJSONObject: ["goal": goal, "days_per_week": daysPerWeek, "pace": pace,
                                                               "weight_kg": weightKg, "goal_weight_kg": goalWeightKg])
        let (data, s) = try await authed(restURL("profiles", query: [.init(name: "id", value: "eq.\(uid)")]),
                                         method: "PATCH", body: body, prefer: "return=minimal")
        guard s == 204 || s == 200 else { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
    }

    // Current plan-driving inputs, to pre-fill the regenerate questionnaire.
    func planInputs() async throws -> (goal: String?, days: Int?, pace: String?, weightKg: Double?, goalWeightKg: Double?) {
        guard let uid = userId else { return (nil, nil, nil, nil, nil) }
        let (data, s) = try await authed(restURL("profiles", query: [
            .init(name: "select", value: "goal,days_per_week,pace,weight_kg,goal_weight_kg"),
            .init(name: "id", value: "eq.\(uid)"), .init(name: "limit", value: "1"),
        ]), method: "GET")
        struct Row: Decodable { let goal: String?; let days_per_week: Int?; let pace: String?; let weight_kg: Double?; let goal_weight_kg: Double? }
        guard s == 200, let rows = try? JSONDecoder().decode([Row].self, from: data), let r = rows.first else { return (nil, nil, nil, nil, nil) }
        return (r.goal, r.days_per_week, r.pace, r.weight_kg, r.goal_weight_kg)
    }

    private func signUp() async throws {
        let url = Config.baseURL.appending(path: "auth/v1/signup")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": Config.devEmail, "password": Config.devPassword,
        ])
        _ = try await URLSession.shared.data(for: req) // ignore "already registered"
    }

    // MARK: scan
    func scan(images: [ImageInput], sex: String = "male") async throws -> ScoreCard {
        try await ensureSession()
        guard let token = accessToken else { throw APIError.noSession }

        let url = Config.baseURL.appending(path: "functions/v1/scan")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONEncoder().encode(ScanRequest(
            sex: sex,
            images: images.map { .init(mimeType: $0.mimeType, dataB64: $0.dataB64) }
        ))

        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = code(resp)
        guard status == 200 else {
            throw APIError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        guard let wrapped = try? JSONDecoder().decode(ScanResponse.self, from: data) else {
            throw APIError.decode
        }
        return wrapped.scan
    }

    // MARK: plan
    struct PlanBundle { let content: PlanContent; let scan: ScoreCard; var id: String? = nil; var startedAt: String? = nil }
    private var cachedPlan: PlanBundle?

    // Generate a fresh plan right after a scan (while the user reads the score card),
    // so opening the plan is instant. This is the only path that calls Gemini.
    func prefetchPlan() async { _ = try? await generatePlan() }
    func clearPlanCache() { cachedPlan = nil }

    // Returns the plan without regenerating when possible: memory cache → the last
    // saved plan in the DB (fast) → generate as a last resort.
    func plan() async throws -> PlanBundle {
        if let cachedPlan { return cachedPlan }
        if let saved = try? await fetchLatestPlan() { cachedPlan = saved; return saved }
        return try await generatePlan()
    }

    private func generatePlan() async throws -> PlanBundle {
        try await ensureSession()
        guard let token = accessToken else { throw APIError.noSession }
        let url = Config.baseURL.appending(path: "functions/v1/plan")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = "{}".data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = code(resp)
        guard status == 200 else { throw APIError.http(status, String(data: data, encoding: .utf8) ?? "") }
        guard let wrapped = try? JSONDecoder().decode(PlanResponse.self, from: data) else { throw APIError.decode }
        let bundle = PlanBundle(content: wrapped.content, scan: wrapped.scan)
        cachedPlan = bundle
        return bundle
    }

    // Rebuild the latest plan from the DB (the /plan function persists each one).
    // Prefer the active plan; fall back to plain-latest if the status column isn't
    // deployed yet (migration is the user's step).
    func fetchLatestPlan() async throws -> PlanBundle? {
        func query(activeOnly: Bool) -> [URLQueryItem] {
            var q: [URLQueryItem] = [
                .init(name: "select", value: "id,workout,macros,scan_id,created_at"),
                .init(name: "order", value: "created_at.desc"),
                .init(name: "limit", value: "1"),
            ]
            if activeOnly { q.append(.init(name: "status", value: "eq.active")) }
            return q
        }
        var (data, s) = try await authed(restURL("plans", query: query(activeOnly: true)), method: "GET")
        if s == 400 { (data, s) = try await authed(restURL("plans", query: query(activeOnly: false)), method: "GET") }
        guard s == 200,
              let rows = try? JSONDecoder().decode([SavedPlanRow].self, from: data),
              let row = rows.first, let scanId = row.scan_id else { return nil }
        let (sd, ss) = try await authed(restURL("scans", query: [
            .init(name: "select", value: "*"),
            .init(name: "id", value: "eq.\(scanId)"),
            .init(name: "limit", value: "1"),
        ]), method: "GET")
        guard ss == 200,
              let scans = try? JSONDecoder().decode([ScoreCard].self, from: sd),
              let scan = scans.first else { return nil }
        let w = row.workout
        let content = PlanContent(
            goal_label: w.goal_label, summary: w.summary, macros: row.macros,
            weekly_split: w.weekly_split, priorities: w.priorities,
            muscle_breakdown: w.muscle_breakdown, projection: w.projection,
            split_critique: w.split_critique, split_changes: w.split_changes)
        return PlanBundle(content: content, scan: scan, id: row.id, startedAt: row.created_at)
    }

    // The user's most recent scan (for the Progress header / share card — independent of which plan is active).
    func latestScan() async throws -> ScoreCard? {
        let (data, s) = try await authed(restURL("scans", query: [
            .init(name: "select", value: "*"),
            .init(name: "order", value: "created_at.desc"),
            .init(name: "limit", value: "1"),
        ]), method: "GET")
        guard s == 200, let scans = try? JSONDecoder().decode([ScoreCard].self, from: data) else { return nil }
        return scans.first
    }

    struct PastPlan: Identifiable, Sendable { let id: String; let date: String?; let goalLabel: String }

    // Finished / archived plans, newest first (history). Empty if the status column isn't deployed.
    func pastPlans() async throws -> [PastPlan] {
        let (data, s) = try await authed(restURL("plans", query: [
            .init(name: "select", value: "id,workout,created_at"),
            .init(name: "status", value: "in.(finished,archived)"),
            .init(name: "order", value: "created_at.desc"),
            .init(name: "limit", value: "30"),
        ]), method: "GET")
        guard s == 200, let rows = try? JSONDecoder().decode([SavedPlanRow].self, from: data) else { return [] }
        return rows.compactMap { r in r.id.map { PastPlan(id: $0, date: r.created_at, goalLabel: r.workout.goal_label) } }
    }

    // Load one specific plan by id (read-only history view).
    func loadPlan(_ id: String) async throws -> PlanBundle? {
        let (data, s) = try await authed(restURL("plans", query: [
            .init(name: "select", value: "id,workout,macros,scan_id,created_at"),
            .init(name: "id", value: "eq.\(id)"), .init(name: "limit", value: "1"),
        ]), method: "GET")
        guard s == 200, let rows = try? JSONDecoder().decode([SavedPlanRow].self, from: data),
              let row = rows.first, let scanId = row.scan_id else { return nil }
        let (sd, ss) = try await authed(restURL("scans", query: [
            .init(name: "select", value: "*"), .init(name: "id", value: "eq.\(scanId)"), .init(name: "limit", value: "1"),
        ]), method: "GET")
        guard ss == 200, let scans = try? JSONDecoder().decode([ScoreCard].self, from: sd), let scan = scans.first else { return nil }
        let w = row.workout
        let content = PlanContent(goal_label: w.goal_label, summary: w.summary, macros: row.macros,
            weekly_split: w.weekly_split, priorities: w.priorities, muscle_breakdown: w.muscle_breakdown,
            projection: w.projection, split_critique: w.split_critique, split_changes: w.split_changes)
        return PlanBundle(content: content, scan: scan, id: row.id, startedAt: row.created_at)
    }

    // MARK: plan lifecycle (active → archived/finished, delete, regenerate)
    func setPlanStatus(_ id: String, _ status: String) async throws {
        struct Body: Encodable { let status: String; let finished_at: String? }
        let finishedAt = status == "finished" ? ISO8601DateFormatter().string(from: Date()) : nil
        let body = try JSONEncoder().encode(Body(status: status, finished_at: finishedAt))
        let (data, s) = try await authed(restURL("plans", query: [.init(name: "id", value: "eq.\(id)")]),
                                         method: "PATCH", body: body, prefer: "return=minimal")
        guard s == 204 || s == 200 else { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
        clearPlanCache()
    }

    func deletePlan(_ id: String) async throws {
        let (data, s) = try await authed(restURL("plans", query: [.init(name: "id", value: "eq.\(id)")]),
                                         method: "DELETE", prefer: "return=minimal")
        guard s == 204 || s == 200 else { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
        clearPlanCache()
    }

    // Build a fresh plan from the latest scan (new active block). Archives the current
    // one first when we know its id so only one plan stays active.
    func regeneratePlan(archiving currentId: String?) async throws -> PlanBundle {
        if let currentId { try? await setPlanStatus(currentId, "archived") }
        clearPlanCache()
        let generated = try await generatePlan()      // inserts a new active plan row
        clearPlanCache()
        return (try? await fetchLatestPlan()) ?? generated   // re-fetch to pick up its id
    }

    private struct PlanResponse: Decodable { let content: PlanContent; let scan: ScoreCard }
    private struct SavedPlanRow: Decodable {
        let id: String?
        let created_at: String?
        let workout: WorkoutBlob
        let macros: PlanContent.Macros
        let scan_id: String?
        struct WorkoutBlob: Decodable {
            let goal_label: String
            let summary: String
            let weekly_split: [PlanContent.Day]
            let priorities: [PlanContent.Priority]
            let muscle_breakdown: [PlanContent.Breakdown]
            let projection: PlanContent.Projection
            let split_critique: String?
            let split_changes: [PlanContent.SplitChange]?
        }
    }

    // MARK: logging (workouts, meals, streak)
    private func restURL(_ table: String, query: [URLQueryItem] = []) -> URL {
        var c = URLComponents(url: Config.baseURL.appending(path: "rest/v1/\(table)"), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { c.queryItems = query }
        return c.url!
    }
    private func authed(_ url: URL, method: String, body: Data? = nil, prefer: String? = nil) async throws -> (Data, Int) {
        try await ensureSession()
        guard let token = accessToken else { throw APIError.noSession }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        req.httpBody = body
        let (data, resp) = try await URLSession.shared.data(for: req)
        return (data, code(resp))
    }

    func logWorkout(dayLabel: String, exercises: [LoggedExercise]) async throws {
        try await ensureSession()
        guard let uid = userId else { throw APIError.noSession }
        struct Row: Encodable { let user_id: String; let day_label: String; let exercises: [LoggedExercise]; let log_date: String }
        let body = try JSONEncoder().encode(Row(user_id: uid, day_label: dayLabel, exercises: exercises, log_date: LogDate.today))
        let (data, s) = try await authed(restURL("workout_logs"), method: "POST", body: body, prefer: "return=minimal")
        guard s == 201 || s == 204 else { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
    }

    // Distinct training dates (for the streak) + whether today is already logged.
    func workoutDates() async throws -> [String] {
        let (data, s) = try await authed(
            restURL("workout_logs", query: [.init(name: "select", value: "log_date"),
                                            .init(name: "order", value: "log_date.desc")]),
            method: "GET")
        guard s == 200 else { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
        struct R: Decodable { let log_date: String }
        return (try? JSONDecoder().decode([R].self, from: data).map { $0.log_date }) ?? []
    }

    // Transcribe a photo of a written routine into text (onboarding split step).
    func readSplit(_ image: ImageInput) async throws -> String {
        try await ensureSession()
        guard let token = accessToken else { throw APIError.noSession }
        var req = URLRequest(url: Config.baseURL.appending(path: "functions/v1/read-split"))
        req.httpMethod = "POST"; req.timeoutInterval = 60
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        struct Body: Encodable { let image: Img; struct Img: Encodable { let mimeType: String; let dataB64: String } }
        req.httpBody = try JSONEncoder().encode(Body(image: .init(mimeType: image.mimeType, dataB64: image.dataB64)))
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard code(resp) == 200 else { throw APIError.http(code(resp), String(data: data, encoding: .utf8) ?? "") }
        struct Wrap: Decodable { let text: String }
        return (try? JSONDecoder().decode(Wrap.self, from: data))?.text ?? ""
    }

    // Search the food catalog (USDA + OpenFoodFacts) via the food-search function.
    func searchFoods(_ q: String) async throws -> [FoodHit] {
        try await ensureSession()
        guard let token = accessToken else { throw APIError.noSession }
        var req = URLRequest(url: Config.baseURL.appending(path: "functions/v1/food-search"))
        req.httpMethod = "POST"; req.timeoutInterval = 30
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["q": q])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard code(resp) == 200 else { return [] }
        struct Wrap: Decodable { let foods: [FoodHit] }
        return (try? JSONDecoder().decode(Wrap.self, from: data))?.foods ?? []
    }

    func scanMeal(_ image: ImageInput, mode: String = "meal") async throws -> MealEstimate {
        try await ensureSession()
        guard let token = accessToken else { throw APIError.noSession }
        var req = URLRequest(url: Config.baseURL.appending(path: "functions/v1/meal-scan"))
        req.httpMethod = "POST"; req.timeoutInterval = 60
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        struct Body: Encodable { let image: Img; let mode: String; struct Img: Encodable { let mimeType: String; let dataB64: String } }
        req.httpBody = try JSONEncoder().encode(Body(image: .init(mimeType: image.mimeType, dataB64: image.dataB64), mode: mode))
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard code(resp) == 200 else { throw APIError.http(code(resp), String(data: data, encoding: .utf8) ?? "") }
        struct Wrap: Decodable { let meal: MealEstimate }
        guard let w = try? JSONDecoder().decode(Wrap.self, from: data) else { throw APIError.decode }
        return w.meal
    }

    // "I'm craving X" → an intensity-tuned version that still fits the day's macros.
    func craving(_ text: String, intensity: String, goal: String, dailyCalories: Double,
                 remaining: (cals: Double, p: Double, c: Double, f: Double)) async throws -> CravingResult {
        try await ensureSession()
        guard let token = accessToken else { throw APIError.noSession }
        var req = URLRequest(url: Config.baseURL.appending(path: "functions/v1/craving"))
        req.httpMethod = "POST"; req.timeoutInterval = 45
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "craving": text, "intensity": intensity, "goal": goal,
            "target": ["calories": dailyCalories],
            "remaining": ["calories": remaining.cals, "protein_g": remaining.p, "carbs_g": remaining.c, "fat_g": remaining.f],
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard code(resp) == 200 else { throw APIError.http(code(resp), String(data: data, encoding: .utf8) ?? "") }
        struct Wrap: Decodable { let craving: CravingResult }
        guard let w = try? JSONDecoder().decode(Wrap.self, from: data) else { throw APIError.decode }
        return w.craving
    }

    // Barcode → product via OpenFoodFacts (through food-search).
    func searchBarcode(_ barcode: String) async throws -> FoodHit? {
        try await ensureSession()
        guard let token = accessToken else { throw APIError.noSession }
        var req = URLRequest(url: Config.baseURL.appending(path: "functions/v1/food-search"))
        req.httpMethod = "POST"; req.timeoutInterval = 30
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["barcode": barcode])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard code(resp) == 200 else { return nil }
        struct Wrap: Decodable { let foods: [FoodHit] }
        return (try? JSONDecoder().decode(Wrap.self, from: data))?.foods.first
    }

    // The component foods at the logged amount (scaled by servings), or a single
    // food synthesized from the totals when there are no items.
    private func scaledItems(_ m: MealEstimate) -> [MealEstimate.Item] {
        if m.items.isEmpty {
            return [.init(name: m.name, portion: nil, calories: m.shownCalories,
                          protein_g: m.shownProtein, carbs_g: m.shownCarbs, fat_g: m.shownFat)]
        }
        return m.items.map { it in
            .init(name: it.name, portion: it.portion,
                  calories: (it.calories * m.servings).rounded(), protein_g: (it.protein_g * m.servings).rounded(),
                  carbs_g: (it.carbs_g * m.servings).rounded(), fat_g: (it.fat_g * m.servings).rounded())
        }
    }

    func logMeal(_ m: MealEstimate, mealType: String = "other") async throws {
        try await ensureSession()
        guard let uid = userId else { throw APIError.noSession }
        let items = scaledItems(m)
        struct Row: Encodable {
            let user_id: String; let log_date: String; let name: String
            let calories: Double; let protein_g: Double; let carbs_g: Double; let fat_g: Double
            var meal_type: String?; var items: [MealEstimate.Item]?
        }
        // Tier down independently so meal_type still saves even if `items` isn't deployed.
        func post(type: Bool, items withItems: Bool, throwOnFail: Bool) async throws -> Int {
            let row = Row(user_id: uid, log_date: LogDate.today, name: m.name,
                          calories: m.shownCalories, protein_g: m.shownProtein, carbs_g: m.shownCarbs,
                          fat_g: m.shownFat, meal_type: type ? mealType : nil, items: withItems ? items : nil)
            let body = try JSONEncoder().encode(row)
            let (data, s) = try await authed(restURL("meal_logs"), method: "POST", body: body, prefer: "return=minimal")
            if s != 201 && s != 204 && throwOnFail { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
            return s
        }
        if try await post(type: true, items: true, throwOnFail: false) == 400 {           // items column missing?
            if try await post(type: true, items: false, throwOnFail: false) == 400 {       // meal_type missing too?
                _ = try await post(type: false, items: false, throwOnFail: true)
            }
        }
    }

    // MARK: daily check-in
    func saveCheckIn(mood: Int, confidence: Int, readiness: Int, trainingDay: Bool) async throws {
        try await ensureSession()
        guard let uid = userId else { throw APIError.noSession }
        struct Row: Encodable { let user_id: String; let log_date: String; let mood: Int; let confidence: Int; let readiness: Int; let training_day: Bool }
        let body = try JSONEncoder().encode(Row(user_id: uid, log_date: LogDate.today, mood: mood, confidence: confidence, readiness: readiness, training_day: trainingDay))
        // Upsert one row per day.
        let (data, s) = try await authed(restURL("check_ins", query: [.init(name: "on_conflict", value: "user_id,log_date")]),
                                         method: "POST", body: body, prefer: "resolution=merge-duplicates,return=minimal")
        guard s == 201 || s == 204 || s == 200 else { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
    }

    func recentCheckIns(limit: Int = 60) async throws -> [CheckIn] {
        let (data, s) = try await authed(restURL("check_ins", query: [
            .init(name: "select", value: "*"), .init(name: "order", value: "log_date.desc"),
            .init(name: "limit", value: "\(limit)")]), method: "GET")
        guard s == 200 else { return [] }
        return (try? JSONDecoder().decode([CheckIn].self, from: data)) ?? []
    }

    // MARK: saved meals (named combos)
    func saveMeal(_ m: MealEstimate) async throws {
        try await ensureSession()
        guard let uid = userId else { throw APIError.noSession }
        struct Row: Encodable {
            let user_id: String; let name: String; let items: [MealEstimate.Item]
            let calories: Double; let protein_g: Double; let carbs_g: Double; let fat_g: Double
        }
        let body = try JSONEncoder().encode(Row(user_id: uid, name: m.name, items: m.items,
            calories: m.baseCalories, protein_g: m.baseProtein, carbs_g: m.baseCarbs, fat_g: m.baseFat))
        let (data, s) = try await authed(restURL("saved_meals"), method: "POST", body: body, prefer: "return=minimal")
        guard s == 201 || s == 204 else { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
    }

    func savedMeals() async throws -> [SavedMeal] {
        let (data, s) = try await authed(restURL("saved_meals", query: [
            .init(name: "select", value: "*"), .init(name: "order", value: "created_at.desc")]), method: "GET")
        guard s == 200 else { return [] }
        return (try? JSONDecoder().decode([SavedMeal].self, from: data)) ?? []
    }

    func deleteSavedMeal(_ id: String) async throws {
        let (data, s) = try await authed(restURL("saved_meals", query: [.init(name: "id", value: "eq.\(id)")]),
                                         method: "DELETE", prefer: "return=minimal")
        guard s == 204 || s == 200 else { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
    }

    // Update an already-logged meal in place (edit flow).
    func updateMeal(id: String, name: String, calories: Double, protein_g: Double,
                    carbs_g: Double, fat_g: Double, mealType: String?, items: [MealEstimate.Item]? = nil) async throws {
        struct Patch: Encodable {
            let name: String; let calories: Double; let protein_g: Double
            let carbs_g: Double; let fat_g: Double; var meal_type: String?; var items: [MealEstimate.Item]?
        }
        func patch(type: Bool, items withItems: Bool, throwOnFail: Bool) async throws -> Int {
            let body = try JSONEncoder().encode(Patch(name: name, calories: calories, protein_g: protein_g,
                carbs_g: carbs_g, fat_g: fat_g, meal_type: type ? mealType : nil, items: withItems ? items : nil))
            let (data, s) = try await authed(restURL("meal_logs", query: [.init(name: "id", value: "eq.\(id)")]),
                                             method: "PATCH", body: body, prefer: "return=minimal")
            if s != 204 && s != 200 && throwOnFail { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
            return s
        }
        if try await patch(type: true, items: true, throwOnFail: false) == 400 {
            if try await patch(type: true, items: false, throwOnFail: false) == 400 {
                _ = try await patch(type: false, items: false, throwOnFail: true)
            }
        }
    }

    func meals(on date: String) async throws -> [MealLog] {
        let (data, s) = try await authed(
            restURL("meal_logs", query: [.init(name: "select", value: "*"),
                                         .init(name: "log_date", value: "eq.\(date)"),
                                         .init(name: "order", value: "created_at.desc")]),
            method: "GET")
        guard s == 200 else { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
        return (try? JSONDecoder().decode([MealLog].self, from: data)) ?? []
    }

    // No-photo path: estimate a baseline scan from onboarding answers, save it, return it.
    func estimateScan() async throws -> ScoreCard {
        try await ensureSession()
        guard let uid = userId else { throw APIError.noSession }
        struct P: Decodable { var sex: String?; var experience: String?; var goal: String?; var activity_level: String?; var focus: [String]? }
        let (pd, ps) = try await authed(restURL("profiles", query: [
            .init(name: "select", value: "sex,experience,goal,activity_level,focus"),
            .init(name: "id", value: "eq.\(uid)")]), method: "GET")
        let p = (ps == 200 ? try? JSONDecoder().decode([P].self, from: pd).first : nil) ?? nil
        let focus = Set(p?.focus ?? [])   // areas they want to bring up → estimate them as lagging

        let base: Double = ["beginner": 3.4, "intermediate": 5.2, "advanced": 6.6][p?.experience ?? ""] ?? 4.5
        let active = p?.activity_level == "active" || p?.activity_level == "very_active"
        let score = (base + (active ? 0.3 : 0)).rounded(toPlaces: 1)
        let bf: Double = ["lose_fat": 22, "gain_muscle": 15, "both": 18, "tone": 20][p?.goal ?? ""] ?? 18
        let potential = min(9.5, (score + 2.6)).rounded(toPlaces: 1)
        let symmetry = min(9.0, score + 0.5).rounded(toPlaces: 1)
        let sex = p?.sex ?? "male"
        let tier = Tier.forScore(score).rawValue
        let groups = ["chest", "back", "shoulders", "arms", "legs", "abs"]
        let offs = [0.2, -0.3, 0.0, 0.1, -0.2, 0.1]
        let muscles = zip(groups, offs).map { (g, o) -> ScoreCard.Muscle in
            let want = focus.contains(g) || (g == "abs" && focus.contains("lower_bf"))
            let s = max(1, min(9.5, score + o + (want ? -0.8 : 0))).rounded(toPlaces: 1)
            return ScoreCard.Muscle(group: g, score: s, visible: false, note: want ? "Your focus" : "Estimated")
        }
        let verdict = "Estimated from your answers. Scan a photo any time for your true Stetic Score and a real weak-point breakdown."

        let muscleJSON = muscles.map { ["group": $0.group, "score": $0.score, "visible": $0.visible, "note": $0.note] as [String: Any] }
        let row: [String: Any] = ["user_id": uid, "sex": sex, "aesthetic_score": score, "rank_tier": tier,
            "body_fat": bf, "symmetry": symmetry, "potential": potential, "muscles": muscleJSON,
            "verdict": verdict, "photo_count": 0, "estimated": true]
        let body = try JSONSerialization.data(withJSONObject: row)
        let (d, s) = try await authed(restURL("scans"), method: "POST", body: body, prefer: "return=minimal")
        guard s == 201 || s == 204 else { throw APIError.http(s, String(data: d, encoding: .utf8) ?? "") }
        return ScoreCard(aesthetic_score: score, rank_tier: tier, body_fat: bf, symmetry: symmetry,
                         potential: potential, muscles: muscles, verdict: verdict, estimated: true)
    }

    // Score history for the progress chart (oldest → newest).
    func scanPoints() async throws -> [ScanPoint] {
        let (data, s) = try await authed(restURL("scans", query: [
            .init(name: "select", value: "aesthetic_score,body_fat,potential,rank_tier,created_at"),
            .init(name: "order", value: "created_at.asc")]), method: "GET")
        guard s == 200 else { return [] }
        return (try? JSONDecoder().decode([ScanPoint].self, from: data)) ?? []
    }

    func logWeight(_ kg: Double) async throws {
        try await ensureSession()
        guard let uid = userId else { throw APIError.noSession }
        struct Row: Encodable { let user_id: String; let weight_kg: Double }
        let body = try JSONEncoder().encode(Row(user_id: uid, weight_kg: kg))
        let (data, s) = try await authed(restURL("weight_logs"), method: "POST", body: body, prefer: "return=minimal")
        guard s == 201 || s == 204 else { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
    }

    func weightPoints() async throws -> [WeightPoint] {
        let (data, s) = try await authed(restURL("weight_logs", query: [
            .init(name: "select", value: "weight_kg,logged_at"),
            .init(name: "order", value: "logged_at.asc")]), method: "GET")
        guard s == 200 else { return [] }
        return (try? JSONDecoder().decode([WeightPoint].self, from: data)) ?? []
    }

    // Current + goal weight from the profile (kg).
    func weightTargets() async throws -> (current: Double?, goal: Double?) {
        try await ensureSession()
        guard let uid = userId else { return (nil, nil) }
        let (data, s) = try await authed(restURL("profiles", query: [
            .init(name: "select", value: "weight_kg,goal_weight_kg"),
            .init(name: "id", value: "eq.\(uid)")]), method: "GET")
        struct R: Decodable { let weight_kg: Double?; let goal_weight_kg: Double? }
        guard s == 200, let r = (try? JSONDecoder().decode([R].self, from: data))?.first else { return (nil, nil) }
        return (r.weight_kg, r.goal_weight_kg)
    }

    // Recent logged sessions (for the history list).
    func recentWorkouts(limit: Int = 14) async throws -> [WorkoutLog] {
        let (data, s) = try await authed(restURL("workout_logs", query: [
            .init(name: "select", value: "id,log_date,day_label,exercises"),
            .init(name: "order", value: "log_date.desc"),
            .init(name: "limit", value: "\(limit)")]), method: "GET")
        guard s == 200 else { return [] }
        return (try? JSONDecoder().decode([WorkoutLog].self, from: data)) ?? []
    }

    func deleteMeal(id: String) async throws {
        let (data, s) = try await authed(restURL("meal_logs", query: [.init(name: "id", value: "eq.\(id)")]),
                                         method: "DELETE", prefer: "return=minimal")
        guard s == 204 || s == 200 else { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
    }

    private func code(_ resp: URLResponse) -> Int { (resp as? HTTPURLResponse)?.statusCode ?? -1 }

    private struct ScanRequest: Encodable {
        let sex: String
        let images: [Img]
        struct Img: Encodable { let mimeType: String; let dataB64: String }
    }
    private struct ScanResponse: Decodable { let scan: ScoreCard }
}

private extension Double {
    func rounded(toPlaces n: Int) -> Double { let m = pow(10.0, Double(n)); return (self * m).rounded() / m }
}
