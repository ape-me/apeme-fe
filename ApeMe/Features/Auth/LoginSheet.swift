import SwiftUI
import AuthenticationServices

/// Sign-in as a sheet, in the brand's look: black, Barlow, lime for the one thing to press.
/// From the welcome it is email only; from elsewhere (`app.sheet = .login`) Apple is offered too.
struct LoginSheet: View {
    var emailOnly = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        LoginForm(emailOnly: emailOnly, onClose: { dismiss() }, onDone: { dismiss() })
            .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 18)
            .frame(maxHeight: .infinity, alignment: .top)
            .presentationDetents([.large])
            .presentationBackground(Brand.black)
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
                    Button { withAnimation(.snappy) { codeSent = false; code = ""; error = nil }; focus = .email } label: {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Brand.white).frame(width: 40, height: 40)
                            .background(Brand.charcoal, in: .circle)
                    }
                    .accessibilityLabel("Back")
                }
                Spacer()
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Brand.white).frame(width: 40, height: 40)
                            .background(Brand.charcoal, in: .circle)
                    }
                    .accessibilityLabel("Close")
                }
            }

            // One Text per line so the lines can sit as tight as the kit sets them; SwiftUI
            // ignores negative line spacing.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(codeSent ? ["CHECK YOUR", "EMAIL"] : ["WHAT’S YOUR", "EMAIL?"], id: \.self) { line in
                    Text(line).font(Brand.display(48)).foregroundStyle(Brand.white)
                        .frame(height: 48 * 0.9, alignment: .center)
                }
            }
            .padding(.top, 18)
            .id(codeSent)
            .transition(.opacity)
            Group {
                if codeSent {
                    Text("We sent a 6-digit code to \(Text(email).foregroundStyle(Brand.white)).")
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
                    .font(Brand.body(20, semibold: true)).foregroundStyle(Brand.white)
                    .tint(Brand.lime)
                    .padding(.horizontal, 18).frame(height: 62)
                    .background(alignment: .leading) {
                        if email.isEmpty {
                            Text("you@email.com").font(Brand.body(20, semibold: true))
                                .foregroundStyle(Color(hex: 0x55555B)).padding(.horizontal, 18)
                        }
                    }
                    .background(Brand.charcoal, in: .rect(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(focus == .email ? Brand.lime : Brand.line, lineWidth: focus == .email ? 1.5 : 1))
                    .focused($focus, equals: .email)
                    .padding(.top, 28)
            }

            if let error {
                Text(error).font(Brand.body(15)).foregroundStyle(Theme.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                #if DEBUG
                if let detail { Text(detail).font(.system(size: 11)).foregroundStyle(Brand.muted).textSelection(.enabled).padding(.top, 6) }
                #endif
            }

            if !codeSent {
                limeButton(busy == .email ? "SENDING…" : "SEND CODE", enabled: emailValid && busy == nil) { send() }
                    .padding(.top, 18)
                if !emailOnly {
                    Text("or").font(Brand.body(15)).foregroundStyle(Brand.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                    Button { run(.apple) { try await app.auth.loginWithApple() } } label: {
                        HStack(spacing: 10) {
                            if busy == .apple { ProgressView().tint(Brand.black) }
                            else { Image(systemName: "apple.logo").font(.system(size: 19, weight: .semibold)) }
                            Text("Continue with Apple").font(Brand.body(19, semibold: true))
                        }
                        .foregroundStyle(Brand.black)
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .background(Brand.white, in: .rect(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressScale())
                    .disabled(busy != nil)
                }
            } else if busy == .email {
                HStack(spacing: 10) {
                    ProgressView().tint(Brand.lime)
                    Text("Signing you in").font(Brand.body(16, semibold: true)).foregroundStyle(Brand.muted)
                }
                .padding(.top, 20)
            }
        }
        .animation(.snappy(duration: 0.25), value: codeSent)
        .animation(.easeOut(duration: 0.2), value: error)
        .onAppear { focus = codeSent ? .code : .email }
    }

    private func limeButton(_ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Brand.display(22)).tracking(0.6)
                .foregroundStyle(enabled ? Brand.black : Color(hex: 0x5A5A60))
                .frame(maxWidth: .infinity).frame(height: 58)
                .background(enabled ? Brand.lime : Brand.charcoal, in: .rect(cornerRadius: 16, style: .continuous))
                .overlay {
                    if !enabled { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Brand.line, lineWidth: 1) }
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
            if raw.contains("JWKS") { return "Apple sign-in didn't go through on Privy's side. Try again." }
            if raw.contains("authenticationFailure") { return "Sign-in didn't go through. Try again." }
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
                    .font(Brand.display(32)).foregroundStyle(Brand.white)
                    .frame(maxWidth: .infinity).frame(height: 64)
                    .background(Brand.charcoal, in: .rect(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(current ? Brand.lime : (filled ? Color(hex: 0x3A3A40) : Brand.line), lineWidth: current ? 1.5 : 1))
                    .scaleEffect(filled ? 1 : 0.97)
                    .animation(.spring(duration: 0.25, bounce: 0.3), value: filled)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Code, \(code.count) of 6 digits entered")
    }
}
