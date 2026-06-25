import SwiftUI
import AuthenticationServices
import CryptoKit

// Account screen: Sign in with Apple, Google (Supabase OAuth), or email/password.
// A DEBUG "Continue as dev" keeps the simulator flow working.
struct SignInView: View {
    var title: String = "STETIC"
    var subtitle: String = "Scan your physique. Get your plan.\nClimb the ranks."
    var onSignedIn: () -> Void

    @State private var rawNonce = ""
    @State private var error: String?
    @State private var working = false
    @State private var showEmail = false
    @State private var note: String?

    // OAuth web session must be retained while it's on screen.
    @State private var webSession: ASWebAuthenticationSession?
    private let presenter = WebAuthPresenter()

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer()
                Text(title).font(.system(size: 32, weight: .heavy)).tracking(title == "STETIC" ? 4 : 0)
                    .multilineTextAlignment(.center).foregroundStyle(Theme.acc)
                Text(subtitle)
                    .font(.system(size: 15)).multilineTextAlignment(.center).foregroundStyle(Theme.mut).lineSpacing(3)
                    .padding(.horizontal, 30)
                Spacer()

                SignInWithAppleButton(.signIn) { req in
                    rawNonce = Self.randomNonce()
                    req.requestedScopes = [.fullName, .email]
                    req.nonce = Self.sha256(rawNonce)
                } onCompletion: { handleApple($0) }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50).clipShape(RoundedRectangle(cornerRadius: 13))
                .padding(.horizontal, 24)
                .disabled(working)

                googleButton
                emailButton

                if let error { Text(error).font(.system(size: 12)).foregroundStyle(Theme.red) }
                if let note { Text(note).font(.system(size: 12)).foregroundStyle(Theme.acc).multilineTextAlignment(.center).padding(.horizontal, 30) }

                #if DEBUG
                Button("Continue as dev") {
                    working = true
                    Task { try? await ScanAPI.shared.ensureSession(); await MainActor.run { working = false; onSignedIn() } }
                }
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut).padding(.top, 2)
                #endif

                Text("By continuing you agree to our Terms & Privacy Policy.")
                    .font(.system(size: 10.5)).foregroundStyle(Theme.mut).multilineTextAlignment(.center)
                    .padding(.horizontal, 40).padding(.bottom, 16).padding(.top, 4)
            }
        }
        .sheet(isPresented: $showEmail) { EmailAuthSheet(onSignedIn: onSignedIn) }
    }

    private var googleButton: some View {
        Button { Task { await googleSignIn() } } label: {
            HStack(spacing: 8) {
                Image(systemName: "g.circle.fill").font(.system(size: 18))
                Text("Continue with Google").font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 13).fill(Color.white))
            .foregroundStyle(Color.black)
            .padding(.horizontal, 24)
        }
        .disabled(working)
    }

    private var emailButton: some View {
        Button { showEmail = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill").font(.system(size: 15))
                Text("Continue with email").font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 13).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.line, lineWidth: 1)))
            .foregroundStyle(Theme.txt)
            .padding(.horizontal, 24)
        }
        .disabled(working)
    }

    // MARK: Apple
    private func handleApple(_ result: Result<ASAuthorization, Error>) {
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

    // MARK: Google (Supabase OAuth via ASWebAuthenticationSession)
    @MainActor private func googleSignIn() async {
        error = nil; working = true
        defer { working = false }
        do {
            var comps = URLComponents(url: Config.baseURL.appending(path: "auth/v1/authorize"), resolvingAgainstBaseURL: false)!
            comps.queryItems = [.init(name: "provider", value: "google"),
                                .init(name: "redirect_to", value: "stetic://auth-callback")]
            guard let authURL = comps.url else { return }
            let callback = try await webAuth(url: authURL, scheme: "stetic")
            guard let frag = URLComponents(string: callback.absoluteString)?.fragment else { throw URLError(.badServerResponse) }
            let params = Dictionary(frag.split(separator: "&").compactMap { kv -> (String, String)? in
                let p = kv.split(separator: "=", maxSplits: 1)
                guard p.count == 2 else { return nil }
                return (String(p[0]), String(p[1]).removingPercentEncoding ?? String(p[1]))
            }, uniquingKeysWith: { a, _ in a })
            guard let rt = params["refresh_token"], await ScanAPI.shared.applyOAuthRefresh(rt) else {
                throw URLError(.userAuthenticationRequired)
            }
            if let uid = await ScanAPI.shared.currentUserID() { await PurchaseManager.shared.identify(uid) }
            onSignedIn()
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                self.error = "Google sign-in failed — try again."
            }
        }
    }

    private func webAuth(url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { cb, err in
                if let cb { cont.resume(returning: cb) } else { cont.resume(throwing: err ?? URLError(.cancelled)) }
            }
            session.presentationContextProvider = presenter
            session.prefersEphemeralWebBrowserSession = false
            webSession = session
            session.start()
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

// Presentation anchor for the OAuth web session.
final class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// Email / password sign-in + sign-up.
struct EmailAuthSheet: View {
    var onSignedIn: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var working = false
    @State private var error: String?
    @State private var note: String?

    private var canSubmit: Bool { email.contains("@") && password.count >= 6 && !working }

    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(Theme.line).frame(width: 38, height: 5).padding(.top, 10)
            Text(isSignUp ? "Create account" : "Sign in").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)

            TextField("", text: $email, prompt: Text("Email").foregroundStyle(Theme.mut))
                .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                .font(.system(size: 16)).foregroundStyle(Theme.txt).padding(13)
                .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))

            SecureField("", text: $password, prompt: Text("Password (6+ characters)").foregroundStyle(Theme.mut))
                .font(.system(size: 16)).foregroundStyle(Theme.txt).padding(13)
                .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))

            Button { submit() } label: {
                HStack(spacing: 6) {
                    if working { ProgressView().tint(Color(hex: 0x0E0E10)) }
                    Text(isSignUp ? "Create account" : "Sign in").font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity).padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(canSubmit ? Theme.acc : Theme.line))
                .foregroundStyle(canSubmit ? Color(hex: 0x0E0E10) : Theme.mut)
            }
            .disabled(!canSubmit)

            Button { isSignUp.toggle(); error = nil; note = nil } label: {
                Text(isSignUp ? "Have an account? Sign in" : "New here? Create an account")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.acc)
            }
            if let error { Text(error).font(.system(size: 12)).foregroundStyle(Theme.red).multilineTextAlignment(.center) }
            if let note { Text(note).font(.system(size: 12)).foregroundStyle(Theme.acc).multilineTextAlignment(.center) }
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.height(360)])
    }

    private func submit() {
        working = true; error = nil; note = nil
        Task {
            do {
                if isSignUp {
                    let signedIn = try await ScanAPI.shared.signUpEmail(email, password)
                    if !signedIn {
                        await MainActor.run { working = false; note = "Check your email to confirm, then sign in." }
                        return
                    }
                } else {
                    try await ScanAPI.shared.signInEmail(email, password)
                }
                if let uid = await ScanAPI.shared.currentUserID() { await PurchaseManager.shared.identify(uid) }
                await MainActor.run { working = false; dismiss(); onSignedIn() }
            } catch {
                await MainActor.run { working = false; self.error = isSignUp ? "Couldn't create that account." : "Wrong email or password." }
            }
        }
    }
}
