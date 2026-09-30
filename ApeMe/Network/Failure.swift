import Foundation

/// One sentence for anything the API can hand back.
///
/// Every screen used to write its own line and throw the reason away: a region block, an expired
/// session, a server fault and a dead network all came out as "Couldn't load markets." The caller
/// names what it was doing; this decides what to say about it.
enum Failure {
    /// A read that failed. `what` completes "Couldn't load ___" and is only reached when nothing
    /// more specific is known.
    static func loading(_ what: String, _ error: Error) -> String {
        specific(error) ?? "Couldn't load \(what). Pull to refresh."
    }

    /// An action that failed, where there is nothing to re-read.
    static func action(_ error: Error) -> String {
        specific(error) ?? "That didn't go through. Try again."
    }

    /// The reasons worth naming. Anything else is the caller's fallback, because a sentence that
    /// guesses is worse than one that admits the shape of the problem.
    private static func specific(_ error: Error) -> String? {
        if case APIError.regionBlocked = error { return "Trading isn't available in your region yet." }
        if case APIError.marketClosed(let opensAt) = error {
            return opensAt.map { "Closed right now. Opens \($0)." } ?? "This market is closed right now."
        }
        if case APIError.insufficientFunds(let short, let needed, let held) = error {
            if let n = needed, let h = held { return "Needs \(Fmt.cash(n)), you have \(Fmt.cash(h))." }
            return short > 0 ? "Add \(Fmt.cash(short)) USDC first." : "Not enough USDC."
        }
        if case APIError.transport(let e) = error {
            let ns = e as NSError
            if ns.code == NSURLErrorTimedOut { return "That took too long. Try again." }
            return "No connection. Check your network."
        }
        if case APIError.slippageExceeded(let suggested) = error {
            guard let s = suggested else { return "The price moved past your limit. Nothing was charged." }
            return "The price moved past your limit. This route needs about \(String(format: "%g", Double(s) / 100))%."
        }
        if case APIError.decoding = error { return "We couldn't read that response." }
        if case APIError.http(let code, let raw) = error {
            let reason = raw.split(separator: "·").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? raw
            switch code {
            case 401, 403: return "Sign in again."
            case 404: return nil
            case 410: return "That's no longer available."
            case 429: return "Too many requests. Wait a minute."
            case 500...599: return "The server hit an error. Try again."
            default: break
            }
            // snake_case from the backend reads as a sentence: invite_required -> Invite required.
            guard reason != "request failed", reason.contains("_") || reason.contains(" ") else { return nil }
            let words = reason.replacingOccurrences(of: "_", with: " ")
            return words.prefix(1).uppercased() + words.dropFirst() + "."
        }
        return nil
    }
}
