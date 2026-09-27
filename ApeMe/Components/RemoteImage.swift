import SwiftUI

/// Decoded logos kept in memory, so one that has already appeared anywhere in the app shows up
/// instantly on the next screen instead of being downloaded and decoded again. AsyncImage does
/// neither, which is why lists used to fill in a frame at a time while scrolling.
actor ImageCache {
    static let shared = ImageCache()
    private let memory = NSCache<NSURL, UIImage>()
    private var inflight: [URL: Task<UIImage?, Never>] = [:]

    private init() { memory.countLimit = 400 }

    func image(for url: URL) async -> UIImage? {
        if let hit = memory.object(forKey: url as NSURL) { return hit }
        if let running = inflight[url] { return await running.value }
        let task = Task<UIImage?, Never> {
            var req = URLRequest(url: url)
            req.cachePolicy = .returnCacheDataElseLoad
            guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
            return UIImage(data: data)
        }
        inflight[url] = task
        let image = await task.value
        inflight[url] = nil
        if let image { memory.setObject(image, forKey: url as NSURL) }
        return image
    }
}

/// A remote logo with a lettered stand-in for when the image is missing or slow.
struct RemoteImage: View {
    let url: URL?
    let fallback: String
    var fontSize: CGFloat = 15
    /// A stand-in is going to sit next to real marks, so it gets a colour of its own rather than
    /// the same grey square eleven times down a list.
    var tint: Color = Theme.surface2
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            tint
            if let image {
                // Drawn through a flexible layer: `scaledToFill` reports a size bigger than the
                // space it was offered, and on its own it would widen whatever contains it.
                Color.clear
                    .overlay { Image(uiImage: image).resizable().scaledToFill() }
                    .clipped()
            } else if !fallback.isEmpty {
                // The letter replaces the logo, it never sits behind it. Drawn underneath, it
                // showed through every logo with a transparent background — the stray D on DELL.
                Text(fallback)
                    .font(.system(size: fontSize, weight: .bold)).tracking(-0.3)
                    .foregroundStyle(Theme.ink.opacity(0.85))
                    .minimumScaleFactor(0.6).lineLimit(1).padding(.horizontal, 2)
            }
        }
        .animation(.easeOut(duration: 0.18), value: image == nil)
        .task(id: url) {
            guard let url else { image = nil; return }
            if let loaded = await ImageCache.shared.image(for: url) { image = loaded }
        }
    }
}

/// Stock logo: rounded square.
struct Logo: View {
    let url: URL?
    let symbol: String
    var size: CGFloat = 40

    /// Eleven Backpack tickers have no bitmap anywhere, so the initials are the mark. Two
    /// characters tell BB from BROS; one would not.
    private var initials: String {
        String(symbol.uppercased().filter(\.isLetter).prefix(2))
    }

    /// Stable per ticker, so a stock keeps the same colour everywhere it appears.
    private var tint: Color {
        guard url == nil else { return Theme.surface2 }
        var hash = 5381
        for b in symbol.utf8 { hash = (hash &* 33) &+ Int(b) }
        return Color(hue: Double(abs(hash) % 360) / 360, saturation: 0.32, brightness: 0.34)
    }

    var body: some View {
        RemoteImage(url: url, fallback: initials.isEmpty ? String(symbol.prefix(1)) : initials,
                    fontSize: size * 0.34, tint: tint)
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.3))
    }
}
