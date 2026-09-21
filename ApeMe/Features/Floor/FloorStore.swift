import Foundation
import Observation

@Observable @MainActor
final class FloorStore {
    let mint: String
    var stock: Stock?
    var tokens: [TokenCard] = []
    var next: String?
    var sort: FloorSort = .vol24h
    var loading = true
    var loadingMore = false
    var error: String?
    var flashes: [String: Flash] = [:]
    var status: LiveSocket.Status = .connecting
    var launched: String?

    private var socket: LiveSocket?
    private var listener: Task<Void, Never>?
    private var gen = 0
    private var stamp = 0

    init(mint: String) { self.mint = mint }

    var king: King? { stock?.king }
    func isKing(_ t: TokenCard) -> Bool { t.mint == stock?.king?.mint }

    func load(app: AppState) async {
        if stock == nil { stock = app.stocksByMint[mint] }
        gen += 1
        let g = gen
        do {
            let d = try await API.shared.floorTokens(mint, sort: sort)
            guard g == gen else { return }
            stock = d.stock
            app.stocksByMint[mint] = d.stock
            tokens = d.tokens
            next = d.next
            error = nil
        } catch {
            guard g == gen else { return }
            if tokens.isEmpty { self.error = "Couldn't load the floor." }
        }
        loading = false
    }

    func setSort(_ s: FloorSort, app: AppState) {
        guard s != sort else { return }
        sort = s
        Task { await load(app: app) }
    }

    func loadMoreIfNeeded(_ t: TokenCard) {
        guard let next, !loadingMore, tokens.suffix(6).contains(where: { $0.mint == t.mint }) else { return }
        loadingMore = true
        let g = gen
        Task {
            defer { loadingMore = false }
            if let d = try? await API.shared.floorTokens(mint, sort: sort, cursor: next), g == gen {
                let seen = Set(tokens.map(\.mint))
                tokens += d.tokens.filter { !seen.contains($0.mint) }
                self.next = d.next
            }
        }
    }

    func connect(app: AppState) {
        guard socket == nil else { return }
        let s = LiveSocket(room: "stock:\(mint)")
        socket = s
        listener = Task { [weak self] in
            for await ev in s.events {
                guard let self else { return }
                switch ev {
                case .status(let st): status = st
                case .frames(let frames):
                    for f in frames {
                        switch f {
                        case .trade(let t):
                            if tokens.contains(where: { $0.mint == t.mint }) {
                                stamp += 1; flashes[t.mint] = Flash(side: t.side, stamp: stamp)
                            }
                        case .token(let m, let event) where event == "created":
                            Task { await self.insert(m, app: app) }
                        default: break
                        }
                    }
                }
            }
        }
        s.start()
    }

    private func insert(_ m: String, app: AppState) async {
        try? await Task.sleep(for: .seconds(1.5))
        guard let h = try? await API.shared.token(m, fresh: true), !tokens.contains(where: { $0.mint == m }) else { return }
        tokens.insert(h.card, at: 0)
        stamp += 1; flashes[m] = Flash(side: .buy, stamp: stamp)
        app.show("\(h.displaySymbol) just launched on \(stock?.symbol ?? "")")
    }

    func disconnect() {
        listener?.cancel(); listener = nil
        socket?.stop(); socket = nil
    }
}
