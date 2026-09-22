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

/// A remote logo with a lettered stand-in. Many memes ship an empty `image`.
struct RemoteImage: View {
    let url: URL?
    let fallback: String
    var fontSize: CGFloat = 15
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Theme.surface2
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if !fallback.isEmpty {
                // The letter replaces the logo, it never sits behind it. Drawn underneath, it
                // showed through every logo with a transparent background — the stray D on DELL.
                Text(fallback)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(Theme.muted)
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
