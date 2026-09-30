import Foundation
import Observation
import PrivySDK

/// Quote, sign, submit — the same three beats as a swap, and the same rule about raw amounts:
/// what leaves the wallet is an integer of the mint's own units, never derived from the display
/// figure.
@Observable @MainActor
final class WithdrawStore {
    enum Phase { case idle, quoting, ready, signing, submitting, confirming, done, failed }

    var phase: Phase = .idle
    var quote: WithdrawQuote?
    var error: String?
    var signature: String?

    private var inflight: Task<Void, Never>?

    var busy: Bool { [.quoting, .signing, .submitting, .confirming].contains(phase) }

    func reset() {
        inflight?.cancel()
        phase = .idle; quote = nil; error = nil; signature = nil
    }

    func getQuote(from: String, mint: String, amountRaw: String, to: String) {
        inflight?.cancel()
        error = nil
        phase = .quoting
        inflight = Task {
            do {
                let q = try await API.shared.withdrawQuote(from: from, mint: mint, amountRaw: amountRaw, to: to)
                guard !Task.isCancelled else { return }
                quote = q; phase = .ready
            } catch {
                guard !Task.isCancelled else { return }
                self.error = Self.message(error); phase = .failed
            }
        }
    }

    /// Signs with the user's Privy wallet and submits. Only a "pending" submit needs polling; a
    /// confirmed one is already on chain.
    func send(wallet: any EmbeddedSolanaWallet) async {
        guard let q = quote else { return }
        error = nil
        do {
            phase = .signing
            let signed = try await SolanaTx.sign(q.transaction, with: wallet)
            phase = .submitting
            let r = try await API.shared.withdrawSubmit(requestId: q.requestId, signedTransaction: signed)
            signature = r.signature
            if r.status == "confirmed" { phase = .done; return }
            phase = .confirming
            for _ in 0..<20 {
                try await Task.sleep(for: .seconds(2))
                let s = try await API.shared.withdrawStatus(q.requestId)
                signature = s.signature ?? signature
                if s.status == "confirmed" { phase = .done; return }
                if s.status == "failed" { error = "The withdrawal didn't go through. Nothing left your wallet."; phase = .failed; return }
            }
            // Still unconfirmed after 40s. It is signed and submitted, so calling it a failure
            // would send someone to send the same money a second time.
            phase = .done
        } catch {
            self.error = Self.message(error)
            phase = .failed
        }
    }

    /// The backend names the reason. These are the ones worth rewording for someone holding a
    /// phone; anything else is surfaced as sent rather than replaced with a shrug.
    static func message(_ error: Error) -> String {
        if case APIError.marketClosed(let opensAt) = error {
            return opensAt.map { "Closed right now. Opens \($0)." } ?? "This market is closed right now."
        }
        if case APIError.regionBlocked = error { return "Trading isn't available in your region yet." }
        if case APIError.http(let code, let raw) = error {
            let reason = raw.split(separator: "·").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? raw
            let r = reason.lowercased()
            if r.contains("token_account_address") {
                return "That's a token account, not a wallet. Paste the wallet address instead."
            }
            if r.contains("insufficient_balance") { return "You don't hold that much any more." }
            if r.contains("min_amount") { return "Too small to send. USDC withdrawals start at $1." }
            if r.contains("unsupported_token") { return "This token can't be withdrawn." }
            if r.contains("to is the sending wallet") { return "That's this wallet's own address." }
            if r.contains("wallet not found") { return "Sign in again, then try the withdrawal." }
            if r.contains("token not found") { return "We don't know that token." }
            if r.contains("gas_wallet_not_configured") { return "Withdrawals are briefly unavailable. Try again shortly." }
            if code == 410 { return "That quote expired. Check the amount and try again." }
            if code == 429 { return "Too many withdrawals this hour. Try again later." }
            if r.contains("does not match") || r.contains("invalid user signature") {
                return "Something changed while signing. Try again."
            }
            if code == 400, r.contains("base58") || r.contains("validation") || r.contains("pubkey") {
                return "That doesn't look like a Solana address."
            }
            if code >= 500 || (!reason.contains("_") && !reason.contains(" ")) {
                return "The server hit an error. Nothing left your wallet."
            }
            let words = reason.replacingOccurrences(of: "_", with: " ")
            return words.prefix(1).uppercased() + words.dropFirst() + "."
        }
        if case APIError.transport = error { return "No connection. Try again." }
        return "The withdrawal didn't go through. Nothing left your wallet."
    }
}
