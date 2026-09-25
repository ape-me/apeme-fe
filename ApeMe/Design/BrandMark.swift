import SwiftUI

/// The one place the logo lives. When the new artwork is ready, add it to Assets.xcassets as an
/// image set named "Logo" (PDF or SVG, "Preserve Vector Data" on) and the splash, onboarding and
/// anything else showing the mark pick it up with no code change. Until then, a placeholder.
struct BrandMark: View {
    var size: CGFloat = 88

    var body: some View {
        if UIImage(named: "Logo") != nil {
            Image("Logo").resizable().scaledToFit().frame(width: size, height: size)
        } else {
            placeholder
        }
    }

    /// A squircle in the accent with a peak for the A and a live dot on it. Neutral enough to
    /// stand in, finished enough not to look like a hole.
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0x7aa2ff), Color(hex: 0x3f6fe8)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .overlay {
                Canvas { ctx, s in
                    let w = s.width, h = s.height
                    var peak = Path()
                    peak.move(to: CGPoint(x: w * 0.24, y: h * 0.72))
                    peak.addLine(to: CGPoint(x: w * 0.5, y: h * 0.3))
                    peak.addLine(to: CGPoint(x: w * 0.76, y: h * 0.72))
                    ctx.stroke(peak, with: .color(.white),
                               style: StrokeStyle(lineWidth: w * 0.1, lineCap: .round, lineJoin: .round))
                    let d = w * 0.13
                    ctx.fill(Path(ellipseIn: CGRect(x: w * 0.72 - d / 2, y: h * 0.3 - d / 2, width: d, height: d)),
                             with: .color(Color(hex: 0x5fe39a)))
                }
            }
            .frame(width: size, height: size)
            .shadow(color: Color(hex: 0x3f6fe8).opacity(0.45), radius: size * 0.25, y: size * 0.08)
    }
}

/// Mark plus name, for the places that introduce the app rather than decorate it.
struct BrandLockup: View {
    var size: CGFloat = 28
    var body: some View {
        HStack(spacing: size * 0.32) {
            BrandMark(size: size)
            Text("ApeMe").font(.system(size: size * 0.62, weight: .bold)).tracking(-size * 0.02)
        }
    }
}
