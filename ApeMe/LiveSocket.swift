import Foundation

/// One WebSocket to ape-be. Frames are JSON arrays of trades. We send "ping" every 25s, the
/// server answers "pong". On close we reconnect with backoff and tell the owner so it can
/// refetch `/trades` to fill the gap.
@MainActor
final class LiveSocket {
    enum Event {
        case trades([WsTrade])
        case opened(reconnect: Bool)
        case closed
    }

    let events: AsyncStream<Event>
    private var continuation: AsyncStream<Event>.Continuation?
    private let url: URL
    private var runner: Task<Void, Never>?
    private let decoder = JSONDecoder()

    init(path: String) {
        url = URL(string: API.wsBase + path)!
        var c: AsyncStream<Event>.Continuation?
        events = AsyncStream { c = $0 }
        continuation = c
    }

    func start() {
        guard runner == nil else { return }
        runner = Task { [weak self] in await self?.run() }
    }

    func stop() {
        runner?.cancel()
        runner = nil
        continuation?.finish()
    }

    private func run() async {
        let session = URLSession(configuration: .default)
        var attempt = 0
        while !Task.isCancelled {
            let ws = session.webSocketTask(with: url)
            ws.resume()
            continuation?.yield(.opened(reconnect: attempt > 0))

            let pinger = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(25))
                    if Task.isCancelled { break }
                    try? await ws.send(.string("ping"))
                }
            }

            do {
                while !Task.isCancelled {
                    let msg = try await ws.receive()
                    attempt = 0
                    switch msg {
                    case .string(let s): handle(Data(s.utf8))
                    case .data(let d): handle(d)
                    @unknown default: break
                    }
                }
            } catch {
                // fall through to reconnect
            }
            pinger.cancel()
            ws.cancel(with: .goingAway, reason: nil)
            if Task.isCancelled { break }
            continuation?.yield(.closed)
            attempt += 1
            let delay = min(30.0, pow(2.0, Double(attempt - 1)))
            try? await Task.sleep(for: .seconds(delay))
        }
    }

    private func handle(_ data: Data) {
        if data.count <= 4, String(data: data, encoding: .utf8) == "pong" { return }
        if let arr = try? decoder.decode([LenientFrame].self, from: data) {
            let trades = arr.compactMap(\.trade)
            if !trades.isEmpty { continuation?.yield(.trades(trades)) }
        } else if let one = try? decoder.decode(LenientFrame.self, from: data), let t = one.trade {
            continuation?.yield(.trades([t]))
        }
    }
}

/// The contract also allows `{t:"token"}` and `{t:"stats"}` frames; skip anything that isn't a trade.
private struct LenientFrame: Decodable {
    let t: String
    let trade: WsTrade?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        t = try c.decode(String.self, forKey: .t)
        trade = t == "trade" ? try? WsTrade(from: decoder) : nil
    }
    private enum Key: String, CodingKey { case t }
}
