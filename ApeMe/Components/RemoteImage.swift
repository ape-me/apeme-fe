import SwiftUI

/// AsyncImage with a lettered fallback. Many memes ship an empty `image`.
struct RemoteImage: View {
    let url: URL?
    let fallback: String
    var fontSize: CGFloat = 15

    var body: some View {
        ZStack {
            Theme.surface2
            Text(fallback)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(Theme.muted)
            if let url {
                AsyncImage(url: url) { phase in
                    if let img = phase.image { img.resizable().scaledToFill() }
                }
            }
        }
    }
}

/// Stock logo: rounded square.
struct Logo: View {
    let url: URL?
    let symbol: String
    var size: CGFloat = 40

    var body: some View {
        RemoteImage(url: url, fallback: String(symbol.prefix(1)), fontSize: size * 0.38)
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.3))
    }
}

/// Meme avatar: circle.
struct Avatar: View {
    let url: URL?
    let symbol: String
    var size: CGFloat = 40

    var body: some View {
        RemoteImage(url: url, fallback: String(symbol.prefix(2)), fontSize: max(7, size * 0.3))
            .frame(width: size, height: size)
            .clipShape(.circle)
    }
}
