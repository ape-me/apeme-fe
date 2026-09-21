import Foundation

/// Raw JSON by path, in memory and on disk. Screens render the cached copy first, then refresh.
actor ResponseCache {
    struct Entry { let data: Data; let at: Date }

    private var memory: [String: Entry] = [:]
    private let dir: URL

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        dir = base.appending(path: "api", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func get(_ key: String) -> Entry? {
        if let e = memory[key] { return e }
        let url = file(key)
        guard let data = try? Data(contentsOf: url),
              let at = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        else { return nil }
        let e = Entry(data: data, at: at)
        memory[key] = e
        return e
    }

    func set(_ key: String, _ data: Data) {
        memory[key] = Entry(data: data, at: .now)
        try? data.write(to: file(key), options: .atomic)
    }

    private func file(_ key: String) -> URL {
        let safe = key.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined()
        return dir.appending(path: String(safe.prefix(180)))
    }
}
