import SwiftUI

/// Buys vs sells: two labels and a green/red bar.
struct SplitBar: View {
    let a: Int?
    let b: Int?
    var labelA = "buys"
    var labelB = "sells"

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Text(Fmt.n(a)).font(.sub.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(labelA).font(.sub).foregroundStyle(Theme.muted)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text(Fmt.n(b)).font(.sub.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(labelB).font(.sub).foregroundStyle(Theme.muted)
                }
            }
            .monospacedDigit()
            GeometryReader { g in
                let tot = Double((a ?? 0) + (b ?? 0))
                let fa = tot > 0 ? Double(a ?? 0) / tot : 0.5
                HStack(spacing: 4) {
                    Capsule().fill(Theme.green).frame(width: max(0, (g.size.width - 4) * fa))
                    Capsule().fill(Theme.red)
                }
            }
            .frame(height: 4)
        }
    }
}
