import Foundation

extension String {
    /// The handful of entities that actually turn up in news headlines. Kept to a lookup rather
    /// than NSAttributedString's HTML importer, which is main-thread only and far too slow to
    /// run per row while scrolling.
    func decodingHTMLEntities() -> String {
        guard contains("&") else { return self }
        var out = self
        let named: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'",
            "&nbsp;": "\u{00a0}", "&ndash;": "–", "&mdash;": "—", "&hellip;": "…",
            "&rsquo;": "’", "&lsquo;": "‘", "&rdquo;": "”", "&ldquo;": "“",
            "&#39;": "'", "&#x27;": "'", "&#34;": "\"", "&#038;": "&", "&#8217;": "’",
            "&#8216;": "‘", "&#8220;": "“", "&#8221;": "”", "&#8211;": "–", "&#8212;": "—",
        ]
        for (k, v) in named { out = out.replacingOccurrences(of: k, with: v) }
        // Anything numeric left over, decimal or hex.
        if out.contains("&#") {
            out = out.replacingOccurrences(of: "&#[xX]?[0-9A-Fa-f]+;", with: "", options: .regularExpression)
        }
        return out
    }
}
