import SwiftUI

/// `● Live` / `○ Connecting` — the socket state on floors and token pages.
struct StatusChip: View {
    let text: String
    let live: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(live ? Theme.green : Theme.faint).frame(width: 6, height: 6)
            Text(text)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Theme.muted)
    }
}

struct Skeleton: View {
    var height: CGFloat = 14
    @State private var dim = false
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Theme.surface)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .opacity(dim ? 0.5 : 1)
            .onAppear { withAnimation(.easeInOut(duration: 0.6).repeatForever()) { dim = true } }
    }
}

struct EmptyState<Content: View>: View {
    let title: String
    var subtitle: String?
    let extra: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder extra: () -> Content = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.extra = extra()
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.h3)
            if let subtitle { Text(subtitle).font(.sub).foregroundStyle(Theme.muted) }
            extra
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20).padding(.vertical, 32)
    }
}

struct ToastView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.ground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13).padding(.horizontal, 16)
            .background(.white, in: .rect(cornerRadius: 14))
            .shadow(color: .black.opacity(0.5), radius: 15, y: 10)
            .padding(.horizontal, 20)
            .padding(.bottom, 72)
    }
}

struct ErrorBar: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.sub)
            .foregroundStyle(Theme.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Theme.redT, in: .rect(cornerRadius: 12))
            .padding(.horizontal, 20).padding(.top, 12)
    }
}

/// Hairline between major sections.
struct HR: View {
    var full = false
    var body: some View {
        Rectangle().fill(Theme.line).frame(height: 1).padding(.horizontal, full ? 0 : 20)
    }
}
