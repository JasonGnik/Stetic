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
        var experience: String?; var daysPerWeek: Int?; var equipment: String?
        var heightCm: Double; var weightKg: Double; var age: Int
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
        if let v = p.daysPerWeek { body["days_per_week"] = v }
        if let v = p.equipment { body["equipment"] = v }
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

    // Pre-generate the plan right after a scan (while the user reads the score card),
    // so opening the plan is instant — no second loader.
    func prefetchPlan() async { _ = try? await plan() }
    func clearPlanCache() { cachedPlan = nil }

    func plan() async throws -> PlanBundle {
        if let cachedPlan { return cachedPlan }
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
    private struct PlanResponse: Decodable { let content: PlanContent; let scan: ScoreCard }

    private func code(_ resp: URLResponse) -> Int { (resp as? HTTPURLResponse)?.statusCode ?? -1 }

    private struct ScanRequest: Encodable {
        let sex: String
        let images: [Img]
        struct Img: Encodable { let mimeType: String; let dataB64: String }
    }
    private struct ScanResponse: Decodable { let scan: ScoreCard }
}
