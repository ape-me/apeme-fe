import SwiftUI

/// Sign in: Apple first, then email + 6-digit code. Bottom sheet, same shell as Add money.
struct LoginSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focus: Field?
    private enum Field { case email, code }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sign in").h2Text()
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            Text("A wallet is created for you. No seed phrase.").font(.sub).foregroundStyle(Theme.muted)

            Button { run { try await app.auth.loginWithApple() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo").font(.system(size: 17, weight: .semibold))
                    Text("Continue with Apple").font(.system(size: 17, weight: .semibold)).tracking(-0.2)
                }
                .foregroundStyle(Theme.ground)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Color.white, in: .capsule)
            }
            .buttonStyle(PressScale())

            HStack(spacing: 12) {
                Rectangle().fill(Theme.line).frame(height: 1)
                Text("or").font(.sub).foregroundStyle(Theme.faint)
                Rectangle().fill(Theme.line).frame(height: 1)
            }

            if codeSent {
                field("6-digit code", text: $code, keyboard: .numberPad, focus: .code)
                Text("Sent to \(email)").font(.sub).foregroundStyle(Theme.muted)
                BigButton(label: "Sign in", style: .primary) {
                    run { try await app.auth.loginWithCode(code.trimmingCharacters(in: .whitespaces), email: email) }
                }
                .disabled(code.count < 6 || busy).opacity(code.count < 6 ? 0.5 : 1)
                Button("Use a different email") { codeSent = false; code = ""; focus = .email }
                    .font(.sub.weight(.semibold)).foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
            } else {
                field("Email", text: $email, keyboard: .emailAddress, focus: .email)
                BigButton(label: "Send code", style: .primary) {
                    run(stay: true) {
                        try await app.auth.sendCode(to: email.trimmingCharacters(in: .whitespaces))
                        codeSent = true; focus = .code
                    }
                }
                .disabled(!email.contains("@") || busy).opacity(email.contains("@") ? 1 : 0.5)
            }

            if let error {
                Text(error).font(.sub).foregroundStyle(Theme.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Theme.redT, in: .rect(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.large])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
        .overlay { if busy { ProgressView().tint(Theme.ink) } }
        .onAppear { focus = .email }
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

    /// Runs one auth step; closes the sheet on success unless `stay`.
    private func run(stay: Bool = false, _ work: @escaping () async throws -> Void) {
        error = nil; busy = true
        Task {
            defer { busy = false }
            do {
                try await work()
                if !stay {
                    await app.loadWallet()
                    dismiss()
                    app.show(app.auth.address.map { "Signed in · \(Fmt.short($0))" } ?? "Signed in")
                }
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            }
        }
    }
}
