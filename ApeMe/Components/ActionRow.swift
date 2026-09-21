import SwiftUI

/// Coinbase-style round action row: four icons with labels, the first one accent-filled.
struct ActionItem: Identifiable {
    let id: String
    let label: String
    let symbol: String
    var accent = false
    var tone: Color? = nil
    let action: () -> Void
}

struct ActionRow: View {
    let items: [ActionItem]
    @Environment(\.skin) private var skin

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                Button(action: item.action) {
                    VStack(spacing: 8) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(item.tone != nil ? .white : item.accent ? skin.accentInk : skin.accent)
                            .frame(width: 52, height: 52)
                            .background(item.tone ?? (item.accent ? skin.accent : Theme.surface), in: .rect(cornerRadius: 16))
                        Text(item.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.ink)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
