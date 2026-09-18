import SwiftUI

/// Remote image with a lettered fallback. Many memes have an empty `image`.
struct TokenImage: View {
    let url: URL?
    let seed: String
    var size: CGFloat = 44
    var radius: CGFloat = 10

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [Theme.surface2, Theme.line], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(String(seed.prefix(1)).uppercased())
                .font(.display(size * 0.42))
                .foregroundStyle(Theme.faint)
            if let url {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct PhasePill: View {
    let phase: Phase
    let progress: Double?

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label)
        }
        .font(.mono(10, .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
    }

    private var color: Color { phase == .graduated ? Theme.blue : Theme.amber }
    private var label: String {
        switch phase {
        case .graduated: "AMM"
        case .curve: progress.map { String(format: "CURVE %.0f%%", $0) } ?? "CURVE"
        }
    }
}

struct LiveDot: View {
    let on: Bool
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(on ? Theme.green : Theme.faint)
                .frame(width: 6, height: 6)
                .scaleEffect(on && pulse ? 1.35 : 1)
                .opacity(on && pulse ? 0.6 : 1)
            Text(on ? "LIVE" : "OFF")
                .font(.mono(10, .semibold))
                .foregroundStyle(on ? Theme.green : Theme.faint)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { pulse = true } }
    }
}

/// Tint that jumps in on each new `flash.stamp` and fades out.
struct FlashOverlay: View {
    let flash: Flash?
    @State private var alpha = 0.0

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill((flash.map { Theme.side($0.side) } ?? .clear).opacity(alpha))
            .allowsHitTesting(false)
            .onChange(of: flash?.stamp) {
                alpha = 0.28
                withAnimation(.easeOut(duration: 0.9)) { alpha = 0 }
            }
    }
}

struct StatCell: View {
    let label: String
    let value: String
    var color: Color = Theme.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.mono(10)).foregroundStyle(Theme.faint)
            Text(value).font(.mono(15, .semibold)).foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Segmented<T: Hashable & Identifiable>: View {
    let items: [T]
    let selected: T
    let label: (T) -> String
    let onSelect: (T) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                let on = item == selected
                Button { onSelect(item) } label: {
                    Text(label(item))
                        .font(.mono(12, .semibold))
                        .foregroundStyle(on ? Theme.bg : Theme.muted)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(on ? Theme.green : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
    }
}

struct ErrorBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(message).font(.body(13)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button("Retry", action: retry)
                .font(.mono(13, .semibold))
                .foregroundStyle(Theme.bg)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Theme.green, in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

/// Re-renders its content every second so ages tick.
struct Ticking<Content: View>: View {
    @ViewBuilder let content: (Date) -> Content
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in content(ctx.date) }
    }
}
