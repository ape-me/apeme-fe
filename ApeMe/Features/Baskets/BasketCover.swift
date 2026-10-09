import SwiftUI

/// The basket's cover: its own tint, the stocks in it, its name, and whatever number the screen
/// is about. The same block opens the basket page, both sheets and the position page, so a
/// basket looks like itself everywhere. The backend sends no art, so the tint comes from the id
/// and never changes between screens or launches.
struct BasketCover<Trailing: View>: View {
    let id: String
    let name: String
    var tagline: String? = nil
    let logos: [URL]
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                LogoStack(urls: logos, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.system(size: 20, weight: .semibold)).tracking(-0.5).foregroundStyle(Theme.ink)
                    if let tagline {
                        Text(tagline).font(.sub).foregroundStyle(Theme.muted).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background(BasketTint.gradient(id), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
    }
}

/// One pastel per basket. Eight pairs that sit in the app's light world, picked by a stable hash
/// of the id: a random hue would land on sickly greens as often as not, and a grey would not
/// read as a cover at all.
enum BasketTint {
    private static let pairs: [(UInt32, UInt32)] = [
        (0xDBEAFE, 0xEFF6FF), // sky
        (0xEDE9FE, 0xF5F3FF), // violet
        (0xFCE7F3, 0xFDF2F8), // pink
        (0xFFEDD5, 0xFFF7ED), // peach
        (0xD1FAE5, 0xECFDF5), // mint
        (0xFEF3C7, 0xFFFBEB), // lemon
        (0xCCFBF1, 0xF0FDFA), // teal
        (0xFFE4E6, 0xFFF1F2), // rose
    ]

    /// FNV-1a over the id: the same basket gets the same pair on every launch, unlike `hashValue`.
    private static func index(_ id: String) -> Int {
        var h: UInt32 = 2166136261
        for b in id.utf8 { h = (h ^ UInt32(b)) &* 16777619 }
        return Int(h % UInt32(pairs.count))
    }

    static func gradient(_ id: String) -> LinearGradient {
        let p = pairs[index(id)]
        return LinearGradient(colors: [Color(hex: p.0), Color(hex: p.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
