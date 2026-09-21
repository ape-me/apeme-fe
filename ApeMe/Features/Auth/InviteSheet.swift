import SwiftUI

/// Invite gate. Shown after sign-in while `/v1/me` says `invite_required`, and whenever a gated user taps Buy / Ape.
struct InviteSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    #if DEBUG
    @State private var code = "XNX5KWW6"
    #else
    @State private var code = ""
    #endif
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Invite code").h2Text()
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            Text("ApeMe is invite-only for now. Browsing is open; trading needs a code.")
                .font(.sub).foregroundStyle(Theme.muted).lineSpacing(2)

            TextField("Code", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 20, weight: .semibold)).tracking(2).monospacedDigit()
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .frame(height: 56)
                .background(Theme.surface2, in: .capsule)
                .focused($focused)
                .onSubmit(submit)

            BigButton(label: busy ? "Checking…" : "Unlock trading", style: .primary, action: submit)
                .disabled(code.count < 4 || busy).opacity(code.count < 4 ? 0.5 : 1)

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
        .onAppear { focused = true }
    }

    private func submit() {
        guard !busy else { return }
        error = nil; busy = true
        Task {
            defer { busy = false }
            do {
                try await app.auth.redeemInvite(code)
                dismiss()
                app.show("You're in")
            } catch APIError.http(let status, _) {
                error = switch status {
                case 404: "That code doesn't exist."
                case 410: "That code has been used up."
                case 409: "You're already in."
                case 401: "Sign in first."
                default: "Couldn't check the code. Try again."
                }
                if status == 409 { await app.auth.refreshMe(); dismiss() }
            } catch {
                self.error = "No connection. Try again."
            }
        }
    }
}
