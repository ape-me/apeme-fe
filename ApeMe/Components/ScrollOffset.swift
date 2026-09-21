import SwiftUI

/// Reports the scroll offset of the content it is attached to (iOS 17 compatible).
struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

extension View {
    func reportScrollOffset(in space: String) -> some View {
        background {
            GeometryReader { g in
                Color.clear.preference(key: ScrollOffsetKey.self, value: -g.frame(in: .named(space)).minY)
            }
        }
    }
}
