import SwiftUI

/// What a dot on the chart was: the story, where it ran, how long ago, how big a deal, and what
/// the price did in the hour after. A grouped dot lists its stories; tapping one opens it.
struct ChartEventSheet: View {
    let events: [ChartEvent]
    @Environment(\.dismiss) private var dismiss
    @State private var reading: URL?
    @State private var height: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(events.count == 1 ? "What happened" : "\(events.count) stories").h2Text()
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            if events.count == 1, let e = events.first {
                single(e)
            } else {
                KCard {
                    ForEach(events) { e in
                        Button { reading = e.link } label: { row(e).padding(.vertical, 12).contentShape(.rect) }
                            .buttonStyle(RowPress())
                    }
                }
            }
            Text("A story can land after the move it describes. The dot is when it ran.")
                .font(.system(size: 11)).foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .frame(maxWidth: .infinity, alignment: .top)
        .presentationDetents(height > 0 ? [.height(min(height + 10, UIScreen.main.bounds.height * 0.9))] : [.medium])
        .presentationBackground(Theme.ground)
        .presentationDragIndicator(.visible)
        .sheet(item: $reading) { SafariPage(url: $0).ignoresSafeArea() }
    }

    private func single(_ e: ChartEvent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            row(e)
            if let m = e.moveAfterPct {
                Text("\(Fmt.trailingArrow(m, 1)) in the next hour")
                    .font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.change(m))
            }
            if e.link != nil {
                BigButton(label: "Read story", style: .primary) { reading = e.link }
            }
        }
    }

    private func row(_ e: ChartEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(e.title).font(.system(size: 15, weight: .semibold)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text([e.source, "\(Fmt.ago(e.publishedAt)) ago"].compactMap { $0 }.joined(separator: " · "))
                    .font(.sub).foregroundStyle(Theme.muted)
                Badge(text: e.impact.capitalized, style: e.impact == "critical" ? .red : e.impact == "major" ? .amber : .grey)
                if events.count > 1, let m = e.moveAfterPct {
                    Text(Fmt.trailingArrow(m, 1)).font(.sub.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.change(m))
                }
            }
        }
    }
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }
