import Foundation

// App configuration. Flip `useRemote` to true (or pass STETIC_REMOTE=1) to point
// at the hosted Supabase project instead of the local Docker stack.
//
// Local: the anon key is the well-known local demo JWT (safe to embed for local
// dev only). Remote: paste your project's anon key below (Dashboard → Project
// Settings → API → "anon public"). The anon key is meant to be shipped in the app.
enum Config {
    // Set true to use the hosted project, or run with STETIC_REMOTE=1.
    static let useRemote = ProcessInfo.processInfo.environment["STETIC_REMOTE"] == "1" || true

    // ── Remote (hosted Supabase project) ──
    static let remoteURL = URL(string: "https://bnamfaocppltrcvnbmcv.supabase.co")!
    static let remoteAnonKey = "sb_publishable_inNzfUY7JL3VsImbV37dRg_qggjoR0n"

    // ── Local (Docker stack, ports shifted +30) ──
    static let localURL = URL(string: "http://127.0.0.1:54351")!
    static let localAnonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

    static var baseURL: URL { useRemote ? remoteURL : localURL }
    static var anonKey: String { useRemote ? remoteAnonKey : localAnonKey }

    // Fixed dev account (created on first use). Real auth (Apple Sign In) comes later.
    static let devEmail = "dev@stetic.local"
    static let devPassword = "stetic-dev-pw"

    // RevenueCat PUBLIC SDK key. Paste the App Store app's `appl_...` key once it's
    // created in RevenueCat (Apps → App Store app). Safe to embed (public key).
    // Until set, the paywall falls back to its built-in prices and the dev path.
    static let revenueCatKey = "appl_HuwOnJsXnxvsLWhmOzCXfKQJoGa"
    static var revenueCatConfigured: Bool { revenueCatKey.hasPrefix("appl_") && !revenueCatKey.contains("PASTE") }
    // The entitlement identifier you created in RevenueCat.
    static let entitlementID = "Stetic Pro"
}
