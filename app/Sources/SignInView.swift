import SwiftUI
import AuthenticationServices
import CryptoKit

// First-run gate. "Sign in with Apple" creates/loads the Supabase account; a DEBUG
// "Continue as dev" button keeps the simulator flow working (Apple sign-in needs a device).
struct SignInView: View {
    var onSignedIn: () -> Void
    @State private var rawNonce = ""
    @State private var error: String?
    @State private var working = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Text("STETIC").font(.system(size: 36, weight: .heavy)).tracking(4).foregroundStyle(Theme.acc)
                Text("Scan your physique. Get your plan.\nClimb the ranks.")
                    .font(.system(size: 15)).multilineTextAlignment(.center).foregroundStyle(Theme.mut).lineSpacing(3)
                Spacer()
                SignInWithAppleButton(.signIn) { req in
                    rawNonce = Self.randomNonce()
                    req.requestedScopes = [.fullName, .email]
                    req.nonce = Self.sha256(rawNonce)
                } onCompletion: { handle($0) }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50).clipShape(RoundedRectangle(cornerRadius: 13))
                .padding(.horizontal, 24)
                .disabled(working)

                if let error { Text(error).font(.system(size: 12)).foregroundStyle(Theme.red) }

                #if DEBUG
                Button("Continue as dev") {
                    working = true
                    Task { try? await ScanAPI.shared.ensureSession(); await MainActor.run { working = false; onSignedIn() } }
                }
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut).padding(.top, 4)
                #endif

                Text("By continuing you agree to our Terms & Privacy Policy.")
                    .font(.system(size: 10.5)).foregroundStyle(Theme.mut).multilineTextAlignment(.center)
                    .padding(.horizontal, 40).padding(.bottom, 16).padding(.top, 6)
            }
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                error = "Couldn't read your Apple credentials."; return
            }
            working = true
            Task {
                do {
                    try await ScanAPI.shared.signInWithApple(idToken: idToken, nonce: rawNonce)
                    if let uid = await ScanAPI.shared.currentUserID() { await PurchaseManager.shared.identify(uid) }
                    await MainActor.run { working = false; onSignedIn() }
                } catch {
                    await MainActor.run { working = false; self.error = "Sign in failed — try again." }
                }
            }
        case .failure(let e):
            if (e as? ASAuthorizationError)?.code != .canceled { error = "Sign in failed — try again." }
        }
    }

    static func randomNonce(_ length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in chars[Int.random(in: 0..<chars.count)] })
    }
    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
