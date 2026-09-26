import Foundation

/// One WebSocket room on the backend (`stock:<mint>`, or the user's own order channel). Frames are JSON arrays.
/// We send "ping" every 25s; the server answers "pong". Reconnects with backoff on close.
@MainActor
final class LiveSocket {
    enum Event {
        case frames([WsFrame])
        case status(Status)
    }
    enum Status: String { case connecting = "Connecting", live = "Live", reconnecting = "Reconnecting" }

    let events: AsyncStream<Event>
    private var continuation: AsyncStream<Event>.Continuation?
    private let url: URL
    private var runner: Task<Void, Never>?
    private let decoder = JSONDecoder()

    init(room: String) {
        url = URL(string: API.wsBase + room)!
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
            continuation?.yield(.status(attempt == 0 ? .connecting : .reconnecting))
            let ws = session.webSocketTask(with: url)
            ws.resume()
            if await opened(ws) { attempt = 0; continuation?.yield(.status(.live)) }
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
            attempt += 1
            try? await Task.sleep(for: .seconds(min(30, pow(2, Double(attempt - 1)) * 1.5)))
        }
    }

    /// A protocol-level ping completes once the handshake is done.
    private func opened(_ ws: URLSessionWebSocketTask) async -> Bool {
        await withCheckedContinuation { c in
            ws.sendPing { c.resume(returning: $0 == nil) }
        }
    }

    private func handle(_ data: Data) {
        if data.count <= 4, String(data: data, encoding: .utf8) == "pong" { return }
        if let arr = try? decoder.decode([RawWsFrame].self, from: data) {
            let frames = arr.compactMap(\.frame)
            if !frames.isEmpty { continuation?.yield(.frames(frames)) }
        } else if let one = try? decoder.decode(RawWsFrame.self, from: data), let f = one.frame {
            continuation?.yield(.frames([f]))
        }
    }
}
