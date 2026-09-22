import SwiftUI

/// Full-screen invite gate. Shown after sign-in while `/v1/me` says `invite_required`; the app is not reachable behind it.
struct InviteView: View {
    @Environment(AppState.self) private var app
    #if DEBUG
    @State private var code = "XNX5KWW6"
    #else
    @State private var code = ""
    #endif
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("Invite code").font(.system(size: 40, weight: .semibold)).tracking(-1.8)
            Text("ApeMe is invite-only for now. Drop the code you were given.")
                .font(.system(size: 17)).foregroundStyle(Theme.muted).padding(.top, 6)

            TextField("Code", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 22, weight: .semibold)).tracking(3).monospacedDigit()
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .frame(height: 56)
                .background(Theme.surface2, in: .capsule)
                .focused($focused)
                .onSubmit(submit)
                .padding(.top, 36)

            BigButton(label: busy ? "Checking…" : "Unlock ApeMe", style: .white, action: submit)
                .disabled(code.count < 4 || busy).opacity(code.count < 4 ? 0.5 : 1)
                .padding(.top, 12)

            if let error {
                Text(error).font(.sub).foregroundStyle(Theme.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Theme.redT, in: .rect(cornerRadius: 12))
                    .padding(.top, 12)
            }

            Spacer(minLength: 24)
            HStack(spacing: 4) {
                Text(app.auth.accountLabel.map { "Signed in as \($0)" } ?? "Signed in").foregroundStyle(Theme.muted)
                Text("·").foregroundStyle(Theme.faint)
                Button("Sign out") { Task { await app.signOut() } }.foregroundStyle(Theme.ink).fontWeight(.semibold)
            }
            .font(.sub).frame(maxWidth: .infinity).padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ground)
        .onAppear { focused = true }
    }

    private func submit() {
        guard !busy else { return }
        error = nil; busy = true
        Task {
            defer { busy = false }
            do {
                try await app.auth.redeemInvite(code)
                Haptic.success()
                app.show("You're in")
            } catch APIError.http(let status, _) {
                error = switch status {
                case 404: "That code doesn't exist."
                case 410: "That code has been used up."
                case 409: "You're already in."
                case 401: "Session expired. Sign out and back in."
                default: "Couldn't check the code. Try again."
                }
                if status == 409 { await app.auth.refreshMe() }
            } catch {
                self.error = "No connection. Try again."
            }
        }
    }
}

/// Signed in but `/v1/me` hasn't answered yet (or failed). Never shows the app on a guess.
struct AccountLoadingView: View {
    @Environment(AppState.self) private var app
    let failed: Bool
    var body: some View {
        VStack(spacing: 14) {
            if failed {
                Text("Couldn't reach your account.").font(.system(size: 17, weight: .semibold))
                Text(app.auth.meRaw ?? "").font(.system(size: 11)).foregroundStyle(Theme.faint).lineLimit(3).multilineTextAlignment(.center)
                BigButton(label: "Try again", style: .white, small: true) { Task { await app.auth.refreshMe() } }
                    .fixedSize()
                Button("Sign out") { Task { await app.signOut() } }.font(.sub.weight(.semibold)).foregroundStyle(Theme.muted)
            } else {
                ProgressView().tint(Theme.muted)
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ground)
    }
}
