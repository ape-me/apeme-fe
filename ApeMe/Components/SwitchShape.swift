import SwiftUI

/// An iOS-style switch drawn to the app's colours, for rows that are a button rather than a Toggle.
struct SwitchShape: View {
    let on: Bool
    let tint: Color
    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule().fill(on ? tint : Theme.surface2)
            Circle().fill(.white)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                .padding(2)
        }
        .frame(width: 51, height: 31)
        .animation(.easeOut(duration: 0.2), value: on)
    }
}
