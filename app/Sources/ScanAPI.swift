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
        var sex: String?; var goal: String?; var focus: [String]
        var experience: String?; var currentSplit: String?
        var daysPerWeek: Int?; var equipment: String?
        var heightCm: Double; var weightKg: Double; var age: Int
        var goalWeightKg: Double?
        var activity: String?; var pace: String?
        var attribution: String?
    }

    // MARK: auth (dev) — sign in, or sign up then sign in.
    func ensureSession() async throws {
        if accessToken != nil { return }
        if let tok = try? await signIn() { accessToken = tok; return }
        try await signUp()
        accessToken = try await signIn()
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
    struct PlanBundle { let content: PlanContent; let scan: ScoreCard }
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
    func fetchLatestPlan() async throws -> PlanBundle? {
        let (data, s) = try await authed(restURL("plans", query: [
            .init(name: "select", value: "workout,macros,scan_id"),
            .init(name: "order", value: "created_at.desc"),
            .init(name: "limit", value: "1"),
        ]), method: "GET")
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
        return PlanBundle(content: content, scan: scan)
    }

    private struct PlanResponse: Decodable { let content: PlanContent; let scan: ScoreCard }
    private struct SavedPlanRow: Decodable {
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

    func scanMeal(_ image: ImageInput) async throws -> MealEstimate {
        try await ensureSession()
        guard let token = accessToken else { throw APIError.noSession }
        var req = URLRequest(url: Config.baseURL.appending(path: "functions/v1/meal-scan"))
        req.httpMethod = "POST"; req.timeoutInterval = 60
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        struct Body: Encodable { let image: Img; struct Img: Encodable { let mimeType: String; let dataB64: String } }
        req.httpBody = try JSONEncoder().encode(Body(image: .init(mimeType: image.mimeType, dataB64: image.dataB64)))
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard code(resp) == 200 else { throw APIError.http(code(resp), String(data: data, encoding: .utf8) ?? "") }
        struct Wrap: Decodable { let meal: MealEstimate }
        guard let w = try? JSONDecoder().decode(Wrap.self, from: data) else { throw APIError.decode }
        return w.meal
    }

    func logMeal(_ m: MealEstimate) async throws {
        try await ensureSession()
        guard let uid = userId else { throw APIError.noSession }
        struct Row: Encodable {
            let user_id: String; let log_date: String; let name: String
            let calories: Double; let protein_g: Double; let carbs_g: Double; let fat_g: Double
        }
        let body = try JSONEncoder().encode(Row(user_id: uid, log_date: LogDate.today, name: m.name,
            calories: m.calories, protein_g: m.protein_g, carbs_g: m.carbs_g, fat_g: m.fat_g))
        let (data, s) = try await authed(restURL("meal_logs"), method: "POST", body: body, prefer: "return=minimal")
        guard s == 201 || s == 204 else { throw APIError.http(s, String(data: data, encoding: .utf8) ?? "") }
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
