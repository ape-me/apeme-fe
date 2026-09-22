import Foundation

/// Number formatting. Mirrors the prototype's `fmt` helpers exactly; they are the spec.
enum Fmt {
    private static let subs: [Character] = ["₀","₁","₂","₃","₄","₅","₆","₇","₈","₉"]
    /// The prototype formats with en-US; the app must not vary by device locale.
    static let locale = Locale(identifier: "en_US")

    /// `$1,141.21` · `$0.0143` · `$0.0₅234`. Never scientific notation.
    static func usd(_ n: Double?) -> String {
        guard let n, n.isFinite else { return "—" }
        if n == 0 { return "$0.00" }
        if n < 0 { return "−" + usd(-n) }
        if n >= 1 { return "$" + group(n, 2) }
        if n >= 0.01 {
            // Cash-like values round to cents; only keep 4 decimals when the extra precision is real (tiny prices).
            let c = (n * 100).rounded() / 100
            return "$" + String(format: abs(n - c) < 0.00005 ? "%.2f" : "%.4f", abs(n - c) < 0.00005 ? c : n)
        }
        let e = Int(floor(log10(n)))
        let mantissa = n / pow(10, Double(e))                 // 1.0 ..< 10.0
        var digits = String(Int((mantissa * 100).rounded()))  // 3 significant digits
        if digits.count > 3 { digits = String(digits.prefix(3)) }
        let zeros = -e - 1
        if zeros >= 2 {
            return "$0.0" + String(String(zeros).map { subs[Int(String($0))!] }) + digits
        }
        return "$" + String(format: "%.6f", n)
    }

    /// Whole dollars and the cents separately, so the cents can be muted.
    static func cents(_ n: Double?) -> (whole: String, cents: String)? {
        guard let n, n.isFinite else { return nil }
        let s = group(n, 2)
        let parts = s.split(separator: ".", maxSplits: 1)
        return ("$" + parts[0], "." + (parts.count > 1 ? parts[1] : "00"))
    }

    /// `$69.3K` · `$1.2M` · `$942` · `$3.50`.
    static func big(_ n: Double?, _ p: String = "$") -> String {
        guard let n, n.isFinite else { return "—" }
        let a = abs(n), s = n < 0 ? "−" : ""
        if a >= 1e9 { return s + p + String(format: "%.1fB", a / 1e9) }
        if a >= 1e6 { return s + p + String(format: "%.1fM", a / 1e6) }
        if a >= 1e3 { return s + p + String(format: "%.1fK", a / 1e3) }
        return s + p + String(format: a >= 100 ? "%.0f" : "%.2f", a)
    }

    static func n(_ v: Double?) -> String {
        guard let v, v.isFinite else { return "—" }
        return group(v.rounded(), 0)
    }
    static func n(_ v: Int?) -> String { v.map { group(Double($0), 0) } ?? "—" }

    static func pct(_ n: Double?, _ d: Int = 2) -> String {
        guard let n, n.isFinite else { return "—" }
        let s = n > 0 ? "+" : n < 0 ? "−" : ""
        return s + String(format: "%.\(d)f%%", abs(n))
    }

    static func arrow(_ n: Double?, _ d: Int = 2) -> String {
        guard let n, n.isFinite else { return "—" }
        return (n >= 0 ? "↑ " : "↓ ") + String(format: "%.\(d)f%%", abs(n))
    }

    static func ago(_ ts: Int?, now: Date = .now) -> String {
        guard let ts else { return "—" }
        let s = max(0, Int(now.timeIntervalSince1970) - ts)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        if s < 86400 { return "\(s / 3600)h" }
        return "\(s / 86400)d"
    }

    static func short(_ a: String?) -> String {
        guard let a, a.count > 9 else { return a ?? "—" }
        return a.prefix(4) + "…" + a.suffix(4)
    }

    static func supply(_ s: String?, _ dec: Int) -> String {
        guard let s, let n = Double(s) else { return "—" }
        return big(n / pow(10, Double(dec)), "")
    }

    static func qty(_ n: Double, symbol: String) -> String {
        let s = n > 1000 ? group(n, 0) : trimmed(n, 5)
        return "\(s) \(symbol)"
    }

    static func time(_ ts: Int) -> String {
        Date(timeIntervalSince1970: TimeInterval(ts)).formatted(.dateTime.hour().minute().locale(locale))
    }
    static func dateTime(_ ts: Int) -> String {
        Date(timeIntervalSince1970: TimeInterval(ts)).formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(locale))
    }

    private static func group(_ v: Double, _ decimals: Int) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }
    private static func trimmed(_ v: Double, _ max: Int) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.maximumFractionDigits = max
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }
}
