import SwiftUI

struct Numpad: View {
    let onKey: (String) -> Void
    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
            ForEach(keys, id: \.self) { k in
                Button { onKey(k) } label: {
                    Group {
                        if k == "⌫" { Image(systemName: "delete.left").font(.system(size: 20)) }
                        else { Text(k).font(.system(size: 26, weight: .medium)) }
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity).frame(height: 64)
                    .contentShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(NumpadPress())
                .accessibilityLabel(k == "⌫" ? "Delete" : k)
            }
        }
    }
}

private struct NumpadPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? Theme.surface2 : .clear, in: .rect(cornerRadius: 12))
    }
}
