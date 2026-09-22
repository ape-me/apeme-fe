import SwiftUI

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

/// Small, quiet, centered above the tab bar. Reads as a confirmation, not an alert.
/// Small pill from the top. Green for good news, red for bad.
struct ToastView: View {
    let text: String
    var error = false
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: error ? "xmark.circle.fill" : "checkmark.circle.fill").font(.system(size: 14, weight: .semibold))
            Text(text).font(.system(size: 13, weight: .semibold)).multilineTextAlignment(.center)
        }
        .foregroundStyle(error ? Theme.red : Theme.green)
        .padding(.horizontal, 14).frame(minHeight: 38)
        .background(error ? Theme.redT : Theme.greenT, in: .capsule)
        .overlay(Capsule().stroke((error ? Theme.red : Theme.green).opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 20).padding(.top, 8)
    }
}

/// In-app confirmation: dimmed ground, centered card, one primary action.
struct AppDialog: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let confirm: String
    var destructive = false
    let action: () -> Void

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                        .onTapGesture { isPresented = false }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title).font(.system(size: 20, weight: .semibold)).tracking(-0.4)
                        Text(message).font(.system(size: 15)).foregroundStyle(Theme.muted).lineSpacing(2)
                        HStack(spacing: 10) {
                            BigButton(label: "Cancel", style: .ghost, small: true) { isPresented = false }
                            BigButton(label: confirm, style: destructive ? .danger : .white, small: true) { isPresented = false; action() }
                        }
                        .padding(.top, 14)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface, in: .rect(cornerRadius: 20))
                    .padding(.horizontal, 28)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: isPresented)
    }
}

extension View {
    func appDialog(_ title: String, isPresented: Binding<Bool>, message: String, confirm: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        modifier(AppDialog(isPresented: isPresented, title: title, message: message, confirm: confirm, destructive: destructive, action: action))
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
