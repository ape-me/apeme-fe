import SwiftUI

/// The user's own mix of a basket. Moving one stock rescales the rest so the total stays at
/// 100; a stock at 0 is out of the mix; the preview re-runs the basket on the new mix after a
/// pause in the dragging.
@Observable @MainActor
final class MixStore {
    private(set) var base: [String: Int] = [:]
    private(set) var order: [String] = []
    var weights: [String: Int] = [:]
    var preview: BasketPreview?
    var loading = false
    var error: String?
    private var task: Task<Void, Never>?

    var changed: Bool { weights != base }
    var active: [String] { order.filter { (weights[$0] ?? 0) > 0 } }
    var removed: [String] { order.filter { (weights[$0] ?? 0) == 0 } }
    /// What the quote gets: only the stocks still in.
    var sendable: [String: Int] { weights.filter { $0.value > 0 } }

    func load(_ d: BasketDetail) {
        guard base != d.ownWeights || order != d.stocks.map(\.key) else { return }
        base = d.ownWeights; order = d.stocks.map(\.key); weights = base; preview = nil; error = nil
    }

    /// Sets one stock and spreads the rest over the others in proportion, in steps of five.
    func set(_ t: String, to raw: Int, basket id: String) {
        var v = min(100, max(0, (raw / 5) * 5))
        let others = active.filter { $0 != t }
        if others.isEmpty { v = 100 }                       // the last stock standing is all of it
        let rest = 100 - v
        let sum = others.reduce(0) { $0 + (weights[$1] ?? 0) }
        var next = weights
        next[t] = v
        var given = 0
        for o in others {
            let share = sum > 0 ? Double(weights[o] ?? 0) * Double(rest) / Double(sum) : Double(rest) / Double(others.count)
            let w = Int((share / 5).rounded()) * 5
            next[o] = w; given += w
        }
        // Rounding drift lands on the biggest of the others, so the total is exactly 100.
        if let big = others.max(by: { (next[$0] ?? 0) < (next[$1] ?? 0) }) { next[big] = max(0, (next[big] ?? 0) + (rest - given)) }
        weights = next
        schedule(id)
    }

    func remove(_ t: String, basket id: String) {
        guard active.count > 1 else { return }
        set(t, to: 0, basket: id)
    }

    /// Back in at its original share, taken from the others.
    func restore(_ t: String, basket id: String) { set(t, to: max(5, base[t] ?? 5), basket: id) }

    func reset() { task?.cancel(); weights = base; preview = nil; error = nil; loading = false }

    private func schedule(_ id: String) {
        task?.cancel()
        guard changed else { preview = nil; loading = false; return }
        loading = true
        let w = sendable
        task = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do { preview = try await API.shared.basketPreview(id, weights: w); error = nil }
            catch { if !Task.isCancelled { self.error = Failure.action(error) } }
            loading = false
        }
    }
}

/// The Mix tab: a bar showing the split, the three returns side by side, the chart on the
/// new mix, and one slider per stock with a step either side.
struct MixView: View {
    let d: BasketDetail
    @Bindable var store: MixStore
    @Environment(\.skin) private var skin

    private func leg(_ t: String) -> BasketDetail.Leg? { d.stocks.first { $0.key == t } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            bar
            returns
            chart
            sliders
            if !store.removed.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Out of the mix").font(.sub).foregroundStyle(Theme.muted)
                    FlowChips(items: store.removed) { t in
                        Pill(label: "+ \(leg(t)?.stock.symbol ?? t)", size: .small) { store.restore(t, basket: d.id) }
                    }
                }
            }
            if store.changed {
                BigButton(label: "Reset to \(d.isAI ? "the AI's" : "the basket's") mix", style: .ghost) { Haptic.light(); store.reset() }
            }
        }
    }

    /// One strip, a segment per stock in proportion, the accent fading from the biggest down.
    private var bar: some View {
        let items = store.active.sorted { (store.weights[$0] ?? 0) > (store.weights[$1] ?? 0) }
        return VStack(alignment: .leading, spacing: 8) {
            GeometryReader { g in
                let usable = g.size.width - CGFloat(max(0, items.count - 1)) * 2
                HStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element) { i, t in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(skin.accent.opacity(max(0.18, 1 - Double(i) * 0.14)))
                            .frame(width: max(4, usable * CGFloat(store.weights[t] ?? 0) / 100))
                    }
                }
            }
            .frame(height: 10)
            .animation(.easeOut(duration: 0.2), value: store.weights)
            Text(items.prefix(4).map { "\(leg($0)?.stock.symbol ?? $0) \(store.weights[$0] ?? 0)%" }.joined(separator: " · ") + (items.count > 4 ? " · …" : ""))
                .font(.sub).monospacedDigit().foregroundStyle(Theme.muted).lineLimit(1)
        }
    }

    private var returns: some View {
        let bench = d.performance?.benchmark
        let label = store.preview?.returnLabel ?? d.returnLabel ?? "1Y"
        return HStack(spacing: 0) {
            cell("Basket mix", d.return1y, d.return1y)
            Rectangle().fill(Theme.line).frame(width: 1, height: 30).padding(.horizontal, 10)
            if store.loading { VStack(alignment: .leading, spacing: 3) { Skeleton(height: 15).frame(width: 56); Skeleton(height: 11).frame(width: 48) }.frame(maxWidth: .infinity, alignment: .leading) }
            else { cell("Your mix", store.changed ? store.preview?.return1y : d.return1y, store.changed ? store.preview?.return1y : d.return1y) }
            Rectangle().fill(Theme.line).frame(width: 1, height: 30).padding(.horizontal, 10)
            cell(bench?.name ?? "S&P 500", bench?.returnPct, bench?.returnPct)
        }
        .overlay(alignment: .bottomLeading) {
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.faint).offset(y: 16)
        }
        .padding(.bottom, 14)
    }

    private func cell(_ label: String, _ v: Double?, _ tint: Double?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(v.map { Fmt.trailingArrow($0, abs($0) >= 100 ? 0 : 1) } ?? "—")
                .font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(v == nil ? Theme.faint : Theme.change(tint))
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var chart: some View {
        let pts = (store.changed ? store.preview?.chart?.points : nil) ?? d.chart?.points ?? []
        let bench = d.performance?.benchmark?.points ?? []
        if pts.count > 1 {
            DualLineChart(primary: pts.map { ($0.t, $0.value) }, secondary: bench.map { ($0.t, $0.value) },
                          tint: Theme.change(store.changed ? store.preview?.return1y ?? d.return1y : d.return1y))
                .frame(height: 150)
                .opacity(store.loading ? 0.5 : 1)
                .animation(.easeOut(duration: 0.2), value: store.loading)
        }
    }

    private var sliders: some View {
        KCard {
            ForEach(store.active, id: \.self) { t in
                let w = store.weights[t] ?? 0
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Logo(url: leg(t)?.stock.logoURL, symbol: leg(t)?.stock.symbol ?? t, size: 28)
                        Text(leg(t)?.stock.symbol ?? t).font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text("\(w)%").font(.system(size: 15, weight: .semibold)).monospacedDigit()
                        if store.active.count > 1 {
                            Button { Haptic.light(); store.remove(t, basket: d.id) } label: {
                                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.muted)
                                    .frame(width: 26, height: 26).background(Theme.surface2, in: .circle)
                            }
                            .buttonStyle(.plain).accessibilityLabel("Remove \(leg(t)?.stock.symbol ?? t)")
                        }
                    }
                    HStack(spacing: 10) {
                        step("minus") { store.set(t, to: w - 5, basket: d.id) }
                        Slider(value: Binding(get: { Double(w) }, set: { store.set(t, to: Int($0), basket: d.id) }), in: 0...100, step: 5)
                            .tint(skin.accent)
                        step("plus") { store.set(t, to: w + 5, basket: d.id) }
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }

    private func step(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptic.selection(); action() } label: {
            Image(systemName: symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.ink)
                .frame(width: 30, height: 30).background(Theme.surface2, in: .circle)
        }
        .buttonStyle(.plain)
    }
}

/// Chips that wrap onto new lines as they run out of room.
struct FlowChips<T: Hashable, V: View>: View {
    let items: [T]
    @ViewBuilder let chip: (T) -> V
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { chip($0) }
        }
    }
}
