import Foundation

/// Number formatting for a trading terminal: tiny prices, compact money, ages.
enum Fmt {
    private static let subscripts: [Character] = ["₀","₁","₂","₃","₄","₅","₆","₇","₈","₉"]

    /// `$220.87`, `$0.0143`, `$0.000144`, `$0.0₆308` (six zeros after the point, then 308).
    static func usd(_ v: Double?) -> String {
        guard let v, v.isFinite else { return "—" }
        return "$" + price(v)
    }

    /// Same as `usd` without the sign; used for axis labels and quote-unit prices.
    static func price(_ v: Double) -> String {
        if v == 0 { return "0" }
        if v < 0 { return "-" + price(-v) }
        if v >= 1000 { return group(v, decimals: 2) }
        if v >= 1 { return String(format: "%.2f", v) }
        if v >= 0.01 { return String(format: "%.4f", v) }
        // Zeros between the point and the first significant digit (0.000139 → 3).
        let zeros = Int(ceil(-log10(v) - 1e-9)) - 1
        if zeros <= 3 {
            return String(format: "%.\(zeros + 3)f", v)
        }
        // Three significant digits after a subscript zero count: 0.0₅599.
        let sig = Int((v * pow(10, Double(zeros + 3))).rounded())
        var digits = String(sig)
        if digits.count > 3 { digits = String(digits.prefix(3)) }
        let sub = String(zeros).map { subscripts[Int(String($0))!] }
        return "0.0" + String(sub) + digits
    }

    /// `$69.3K`, `$1.2M`, `$558K`, `$942`.
    static func compact(_ v: Double?, sign: Bool = true) -> String {
        guard let v, v.isFinite else { return "—" }
        let p = sign ? "$" : ""
        let a = abs(v)
        let s: String
        if a >= 1_000_000_000 { s = trim(a / 1_000_000_000) + "B" }
        else if a >= 1_000_000 { s = trim(a / 1_000_000) + "M" }
        else if a >= 1_000 { s = trim(a / 1_000) + "K" }
        else { s = String(format: a >= 100 ? "%.0f" : "%.1f", a) }
        return (v < 0 ? "-" : "") + p + s
    }

    /// Token quantities: `83.3K NIU`, `1.2M`.
    static func qty(_ v: Double) -> String { compact(v, sign: false) }

    static func pct(_ v: Double?) -> String {
        guard let v, v.isFinite else { return "—" }
        return String(format: "%@%.2f%%", v >= 0 ? "+" : "", v)
    }

    static func int(_ v: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }

    /// Age from a chain timestamp. The block clock lags wall time 1–4s, so never negative.
    static func age(_ ts: Int?, now: Date = Date()) -> String {
        guard let ts else { return "—" }
        let s = max(0, Int(now.timeIntervalSince1970) - ts)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        if s < 86400 { return "\(s / 3600)h" }
        return "\(s / 86400)d"
    }

    static func short(_ addr: String) -> String {
        guard addr.count > 9 else { return addr }
        return addr.prefix(4) + "…" + addr.suffix(4)
    }

    static func tax(_ bps: Int) -> String {
        if bps == 0 { return "0%" }
        let p = Double(bps) / 100
        return p == p.rounded() ? String(format: "%.0f%%", p) : String(format: "%.1f%%", p)
    }

    private static func trim(_ v: Double) -> String {
        let s = String(format: v >= 100 ? "%.0f" : "%.1f", v)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }

    private static func group(_ v: Double, decimals: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }
}
