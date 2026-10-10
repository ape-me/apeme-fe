import SwiftUI
import AuthenticationServices

/// Sign-in as a sheet, in the app's look: ground, Instrument Sans, one filled accent button.
/// From the welcome it is email only; from elsewhere (`app.sheet = .login`) Apple is offered too.
struct LoginSheet: View {
    var emailOnly = false
    @Environment(\.dismiss) private var dismiss
    var body: some View { content }

    private var content: some View {
        LoginForm(emailOnly: emailOnly, onClose: { dismiss() }, onDone: { dismiss() })
            .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 18)
            .frame(maxHeight: .infinity, alignment: .top)
            .presentationDetents([.large])
            .presentationBackground(Brand.ground)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
    }
}

/// Email, then a six-digit code that signs in the moment the last digit lands.
struct LoginForm: View {
    var emailOnly = false
    var onClose: (() -> Void)? = nil
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

    private var emailValid: Bool {
        email.trimmingCharacters(in: .whitespaces).range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                if codeSent {
                    IconButton(symbol: "chevron.left", label: "Back") {
                        withAnimation(.snappy) { codeSent = false; code = ""; error = nil }; focus = .email
                    }
                }
                Spacer()
                if let onClose { IconButton(symbol: "xmark", label: "Close", action: onClose) }
            }

            Text(codeSent ? "Check your email" : "What’s your email?")
                .font(.instrument(28, 600)).tracking(-0.6).foregroundStyle(Brand.ink)
                .padding(.top, 18)
                .id(codeSent)
                .transition(.opacity)
            Group {
                if codeSent {
                    Text("We sent a 6-digit code to \(Text(email).foregroundStyle(Brand.ink)).")
                } else {
                    Text("We’ll send you a code. A wallet is set up for you, no seed phrase.")
                }
            }
            .font(Brand.body(17)).foregroundStyle(Brand.muted).lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)

            if codeSent {
                CodeBoxes(code: $code, focused: focus == .code)
                    .padding(.top, 28)
                    .overlay {
                        // The real field, invisible, carrying the keyboard and one-time-code autofill.
                        TextField("", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .focused($focus, equals: .code)
                            .foregroundStyle(.clear).tint(.clear)
                            .padding(.top, 28)
                            .onChange(of: code) { _, v in
                                let digits = String(v.filter(\.isNumber).prefix(6))
                                if digits != v { code = digits }
                                if digits.count == 6 { verify() }
                            }
                    }
                Button("Resend code") { send() }
                    .font(Brand.body(16, semibold: true)).foregroundStyle(Brand.muted)
                    .padding(.top, 20)
                    .disabled(busy != nil)
            } else {
                TextField("", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .submitLabel(.send)
                    .onSubmit { if emailValid { send() } }
                    .font(Brand.body(20, semibold: true)).foregroundStyle(Brand.ink)
                    .tint(Brand.accent)
                    .padding(.horizontal, 18).frame(height: 62)
                    .background(alignment: .leading) {
                        if email.isEmpty {
                            Text("you@email.com").font(Brand.body(20, semibold: true))
                                .foregroundStyle(Theme.faint).padding(.horizontal, 18)
                        }
                    }
                    .background(Brand.surface, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(focus == .email ? Brand.accent : Brand.line, lineWidth: focus == .email ? 1.5 : 1))
                    .focused($focus, equals: .email)
                    .padding(.top, 28)
            }

            if let error {
                Text(error).font(Brand.body(15)).foregroundStyle(Theme.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                #if DEBUG
                if Feature.debugTools, let detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(Brand.muted).textSelection(.enabled).padding(.top, 6)
                }
                #endif
            }

            if !codeSent {
                accentButton(busy == .email ? "Sending…" : "Send code", enabled: emailValid && busy == nil) { send() }
                    .padding(.top, 18)
                if !emailOnly {
                    Text("or").font(Brand.body(15)).foregroundStyle(Brand.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                    Button { run(.apple) { try await app.auth.loginWithApple() } } label: {
                        HStack(spacing: 10) {
                            if busy == .apple { ProgressView().tint(Brand.ground) }
                            else { Image(systemName: "apple.logo").font(.system(size: 19, weight: .semibold)) }
                            Text("Continue with Apple").font(Brand.body(19, semibold: true))
                        }
                        .foregroundStyle(Brand.ground)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(Brand.ink, in: .rect(cornerRadius: 8))
                    }
                    .buttonStyle(PressScale())
                    .disabled(busy != nil)
                }
            } else if busy == .email {
                HStack(spacing: 10) {
                    ProgressView().tint(Brand.accent)
                    Text("Signing you in").font(Brand.body(16, semibold: true)).foregroundStyle(Brand.muted)
                }
                .padding(.top, 20)
            }
        }
        .animation(.snappy(duration: 0.25), value: codeSent)
        .animation(.easeOut(duration: 0.2), value: error)
        .onAppear { focus = codeSent ? .code : .email }
    }

    /// The one filled button on the screen: the thing to press.
    private func accentButton(_ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.instrument(16, 600)).tracking(-0.2)
                .foregroundStyle(enabled ? Color.white : Theme.faint)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(enabled ? Brand.accent : Brand.surface, in: .rect(cornerRadius: 8))
                .overlay {
                    if !enabled { RoundedRectangle(cornerRadius: 8).stroke(Brand.line, lineWidth: 1) }
                }
        }
        .buttonStyle(PressScale())
        .disabled(!enabled)
        .animation(.easeOut(duration: 0.15), value: enabled)
    }

    private func send() {
        run(.email, stay: true) {
            try await app.auth.sendCode(to: email.trimmingCharacters(in: .whitespaces))
            code = ""; codeSent = true; focus = .code
        }
    }

    private func verify() {
        guard busy == nil else { return }
        run(.email, emailCode: true) {
            do { try await app.auth.loginWithCode(code, email: email.trimmingCharacters(in: .whitespaces)) }
            catch { code = ""; Haptic.error(); throw error }
        }
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
            // Privy wraps the real reason several layers deep and every one of them is an
            // `authenticationFailure`, so the specific causes have to be read before that catch-all
            // — otherwise a mistyped code and a dead network give the same useless sentence.
            let r = raw.lowercased()
            if r.contains("invalid_credentials") || r.contains("invalid email and code") {
                return "That code didn't match. Check it, or tap Resend code."
            }
            if r.contains("expired") { return "That code has expired. Tap Resend code for a new one." }
            if r.contains("too_many") || r.contains("rate_limit") { return "Too many tries. Wait a minute, then resend." }
            if r.contains("jwks") { return "Apple sign-in didn't go through on Privy's side. Try again." }
            if r.contains("authenticationfailure") { return "Sign-in didn't go through. Try again." }
        }
        let text = (error as? LocalizedError)?.errorDescription ?? ns.localizedDescription
        if emailCode, text.lowercased().contains("invalid") || text.lowercased().contains("code") { return "That code didn't match. Check it and try again." }
        if text.lowercased().contains("cancel") { return nil }
        return text.isEmpty ? "Something went wrong. Try again." : text
    }
}

/// Six boxes for the code, the next one lit. Display only; the hidden field above does the typing.
private struct CodeBoxes: View {
    @Binding var code: String
    let focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { i in
                let chars = Array(code)
                let filled = i < chars.count
                let current = focused && i == chars.count
                Text(filled ? String(chars[i]) : "")
                    .font(.instrument(26, 600)).monospacedDigit().foregroundStyle(Brand.ink)
                    .frame(maxWidth: .infinity).frame(height: 60)
                    .background(Brand.surface, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(current ? Brand.accent : Brand.line, lineWidth: current ? 1.5 : 1))
                    .scaleEffect(filled ? 1 : 0.97)
                    .animation(.spring(duration: 0.25, bounce: 0.3), value: filled)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Code, \(code.count) of 6 digits entered")
    }
}
