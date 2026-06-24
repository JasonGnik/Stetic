import Foundation

// DEV configuration — points at the local Supabase stack (ports shifted +30).
// The anon key is the well-known local demo JWT (safe to embed for local dev only).
// Production will swap base URL + key and replace dev auth with Apple Sign In.
enum Config {
    static let baseURL = URL(string: "http://127.0.0.1:54351")!
    static let anonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

    // Fixed local dev account (created on first use). Real auth comes later.
    static let devEmail = "dev@stetic.local"
    static let devPassword = "stetic-dev-pw"
}
