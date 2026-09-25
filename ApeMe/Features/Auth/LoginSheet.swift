import SwiftUI
import AuthenticationServices

/// Same form inside a bottom sheet — used when a signed-out state is reached later (sign out from You).
struct LoginSheet: View {
    /// From the welcome screen, where Apple already has its own button.
    var emailOnly = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(emailOnly ? "Continue with email" : "Sign in").h2Text()
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            LoginForm(emailOnly: emailOnly, onDone: { dismiss() })
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.large])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
    }
}

/// Apple first, then email + 6-digit code.
struct LoginForm: View {
    var emailOnly = false
    var onDone: () -> Void = {}
    @Environment(AppState.self) private var app
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    private enum Action { case apple, email }
    @State private var busy: Action? = nil
    @State private var error: String?
    @State private var detail: String?
    @FocusState private var focus: Field?
    private enum Field { case email, code }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A wallet is created for you. No seed phrase.").font(.sub).foregroundStyle(Theme.muted)

            if !emailOnly {
            Button { run(.apple) { try await app.auth.loginWithApple() } } label: {
                HStack(spacing: 8) {
                    if busy == .apple { ProgressView().tint(Theme.ground) }
                    else { Image(systemName: "apple.logo").font(.system(size: 17, weight: .semibold)) }
                    Text("Continue with Apple").font(.system(size: 17, weight: .semibold)).tracking(-0.2)
                }
                .foregroundStyle(Theme.ground)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Color.white, in: .capsule)
            }
            .buttonStyle(PressScale())
            .disabled(busy != nil)

            HStack(spacing: 12) {
                Rectangle().fill(Theme.line).frame(height: 1)
                Text("or").font(.sub).foregroundStyle(Theme.faint)
                Rectangle().fill(Theme.line).frame(height: 1)
            }
            }

            if codeSent {
                field("6-digit code", text: $code, keyboard: .numberPad, focus: .code)
                Text("Sent to \(email)").font(.sub).foregroundStyle(Theme.muted)
                BigButton(label: busy == .email ? "Signing in…" : "Sign in", style: .primary) {
                    run(.email, emailCode: true) { try await app.auth.loginWithCode(code.trimmingCharacters(in: .whitespaces), email: email) }
                }
                .disabled(code.count < 6 || busy != nil).opacity(code.count < 6 ? 0.5 : 1)
                Button("Use a different email") { codeSent = false; code = ""; focus = .email }
                    .font(.sub.weight(.semibold)).foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
            } else {
                field("Email", text: $email, keyboard: .emailAddress, focus: .email)
                BigButton(label: busy == .email ? "Sending…" : "Send code", style: .primary) {
                    run(.email, stay: true) {
                        try await app.auth.sendCode(to: email.trimmingCharacters(in: .whitespaces))
                        codeSent = true; focus = .code
                    }
                }
                .disabled(!email.contains("@") || busy != nil).opacity(email.contains("@") ? 1 : 0.5)
            }

            if let error {
                VStack(alignment: .leading, spacing: 6) {
                    Text(error).font(.sub).foregroundStyle(Theme.red)
                    #if DEBUG
                    if let detail { Text(detail).font(.system(size: 11)).foregroundStyle(Theme.muted).textSelection(.enabled) }
                    #endif
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.redT, in: .rect(cornerRadius: 12))
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType, focus f: Field) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(f == .email ? .emailAddress : .oneTimeCode)
            .font(.system(size: 17, weight: .medium)).monospacedDigit()
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16).frame(height: 52)
            .background(Theme.surface2, in: .capsule)
            .focused($focus, equals: f)
    }

    /// Runs one auth step. On a completed login: load the wallet, hand back, and open the invite gate if needed.
    private func run(_ which: Action, stay: Bool = false, emailCode: Bool = false, _ work: @escaping () async throws -> Void) {
        error = nil; detail = nil; busy = which
        Task {
            defer { busy = nil }
            do {
                try await work()
                if !stay {
                    Haptic.success()
                    app.onboarded = true
                    await app.loadWallet()
                    onDone()
                }
            } catch {
                self.error = Self.message(for: error, emailCode: emailCode)
                self.detail = "\(error)"
                print("[apeme] login failed:", error)
            }
        }
    }

    /// Cancelling is not an error. Everything else gets one plain sentence.
    static func message(for error: Error, emailCode: Bool) -> String? {
        let ns = error as NSError
        if ns.domain == ASAuthorizationError.errorDomain {
            switch ASAuthorizationError.Code(rawValue: ns.code) {
            case .canceled: return nil
            case .notHandled, .unknown: return "Apple sign-in isn't available right now. Try email."
            case .invalidResponse, .failed, .notInteractive: return "Apple sign-in failed. Try again or use email."
            default: return "Apple sign-in failed. Try again or use email."
            }
        }
        if ns.domain == NSURLErrorDomain { return "No connection. Check your network and try again." }
        let raw = "\(error)"
        if raw.contains("PrivyError") {
            if raw.contains("JWKS") { return "Apple sign-in didn't go through on Privy's side. Try again." }
            if raw.contains("authenticationFailure") { return "Sign-in didn't go through. Try again." }
        }
        let text = (error as? LocalizedError)?.errorDescription ?? ns.localizedDescription
        if emailCode, text.lowercased().contains("invalid") || text.lowercased().contains("code") { return "That code didn't match. Check it and try again." }
        if text.lowercased().contains("cancel") { return nil }
        return text.isEmpty ? "Something went wrong. Try again." : text
    }
}
