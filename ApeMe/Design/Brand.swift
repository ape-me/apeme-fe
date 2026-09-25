import SwiftUI
import UIKit

/// Stonks247 brand kit v1: black, lime, white, charcoal; Barlow Condensed Black for display,
/// Barlow for body. The rest of the app still runs on `Theme`; these are for the brand surfaces.
enum Brand {
    static let black = Color(hex: 0x0B0B0C)
    static let lime = Color(hex: 0xD7FF3A)
    static let white = Color(hex: 0xF5F5F2)
    static let charcoal = Color(hex: 0x18181B)
    static let line = Color(hex: 0x2A2A2F)
    static let muted = Color(hex: 0x9A9AA0)

    static let displayFace = "BarlowCondensed-Black"

    /// Display type ignores Dynamic Type on purpose: the logo and the headline are set to a width.
    static func display(_ size: CGFloat) -> Font { .custom(displayFace, fixedSize: size) }
    static func body(_ size: CGFloat, semibold: Bool = false) -> Font {
        .custom(semibold ? "Barlow-SemiBold" : "Barlow-Regular", size: size)
    }
}

/// 24↗7 over STONKS, both rows set to the same width as the kit requires. Built from the font
/// rather than a bitmap so it is sharp at any size and each part can move on its own.
struct LogoMark: View {
    let width: CGFloat
    /// 0 = hidden, 1 = shown. Split so the launch sequence can stage them.
    var top: CGFloat = 1
    var arrow: Int = 2
    var bottom: CGFloat = 1

    var body: some View {
        let m = LogoMetrics(width: width)
        VStack(alignment: .leading, spacing: m.gap) {
            HStack(spacing: m.arrowMargin) {
                Text("24")
                Arrow()
                    .fill(Brand.lime)
                    .frame(width: m.arrowW, height: m.arrowH)
                    .scaleEffect(arrowScale)
                    .offset(x: arrowOffset.width * m.arrowW, y: arrowOffset.height * m.arrowH)
                    .opacity(arrow == 0 ? 0 : 1)
                Text("7")
            }
            .font(Brand.display(m.topSize)).tracking(-0.01 * m.topSize)
            .foregroundStyle(Brand.lime)
            .frame(height: m.topSize * 0.8)
            .scaleEffect(0.35 + 0.65 * top, anchor: UnitPoint(x: 0.5, y: 0.6))
            .opacity(top)

            // Masked, so STONKS rises out of its own line rather than fading in.
            Text("STONKS")
                .font(Brand.display(m.botSize)).tracking(-0.01 * m.botSize)
                .foregroundStyle(Brand.white)
                .frame(height: m.botSize * 0.8)
                .offset(y: (1 - bottom) * m.botSize * 0.8 * 1.1)
                .frame(height: m.botSize * 0.86, alignment: .top)
                .clipped()
        }
        .fixedSize()
    }

    private var arrowScale: CGFloat { [0.3, 1.12, 1][arrow] }
    private var arrowOffset: CGSize { [CGSize(width: -0.6, height: 0.6), CGSize(width: 0.14, height: -0.14), .zero][arrow] }
}

/// The arrow from the kit's SVG (viewBox 44×62): a thick rounded shaft and a solid head.
struct Arrow: Shape {
    func path(in r: CGRect) -> Path {
        let sx = r.width / 44, sy = r.height / 62
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + y * sy) }
        var shaft = Path()
        shaft.move(to: p(9, 54)); shaft.addLine(to: p(25.8, 25.7))
        let body = shaft.strokedPath(StrokeStyle(lineWidth: 13 * sx, lineCap: .round))
        var head = Path()
        head.move(to: p(38, 5)); head.addLine(to: p(37.8, 32.8)); head.addLine(to: p(13.7, 18.5)); head.closeSubpath()
        // A union, not addPath: the stroked shaft and the head wind in opposite directions, so
        // simply adding them cancelled the overlap and punched a notch out of the arrowhead.
        return Path(body.cgPath.union(head.cgPath))
    }
}

/// Font sizes that make both rows exactly `width` wide, measured from the real glyphs.
struct LogoMetrics {
    let topSize, botSize, arrowW, arrowH, arrowMargin, gap, height: CGFloat

    init(width w: CGFloat) {
        let f = UIFont(name: Brand.displayFace, size: 100) ?? .systemFont(ofSize: 100, weight: .black)
        func measure(_ s: String) -> CGFloat {
            (s as NSString).size(withAttributes: [.font: f, .kern: -1.0]).width
        }
        let top100 = measure("24") + measure("7") + 100 * (0.511 + 0.04)
        let bot100 = measure("STONKS")
        topSize = 100 * w / top100
        botSize = 100 * w / bot100
        arrowW = topSize * 0.511
        arrowH = topSize * 0.72
        arrowMargin = topSize * 0.02
        gap = w * 0.035
        height = topSize * 0.8 + gap + botSize * 0.86
    }
}
