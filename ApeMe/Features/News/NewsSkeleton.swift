import SwiftUI

/// A skeleton earns its keep by holding exactly the space the real thing will take, so nothing
/// jumps when the data lands. These mirror NewsRow and the headline card block for block.

/// A bar the width of the text it stands in for.
private struct Bar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12
    var radius: CGFloat = 6
    @State private var dim = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Theme.surface)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .opacity(dim ? 0.45 : 1)
            .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever()) { dim = true } }
    }
}

/// 40pt mark, a meta line, two title lines, a badge — the same rhythm as a loaded row.
struct NewsRowSkeleton: View {
    var showThumb = true
    var titleWidths: (CGFloat, CGFloat) = (1.0, 0.72)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showThumb {
                RoundedRectangle(cornerRadius: 12).fill(Theme.surface).frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 8) {
                Bar(width: 150, height: 11)
                GeometryReader { geo in
                    VStack(alignment: .leading, spacing: 6) {
                        Bar(width: geo.size.width * titleWidths.0, height: 14)
                        Bar(width: geo.size.width * titleWidths.1, height: 14)
                    }
                }
                .frame(height: 34)
                Bar(width: 64, height: 17, radius: 5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
    }
}

struct NewsListSkeleton: View {
    var count = 4
    var showThumb = true
    /// Ragged line lengths read as text; identical bars read as a loading spinner in disguise.
    private let widths: [(CGFloat, CGFloat)] = [(1.0, 0.66), (0.94, 0.8), (1.0, 0.45), (0.88, 0.7), (1.0, 0.6)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { i in
                if i > 0 { Divider().overlay(Theme.line) }
                NewsRowSkeleton(showThumb: showThumb, titleWidths: widths[i % widths.count])
            }
        }
    }
}

/// The same 214pt cards the strip will fill, so the row below never shifts down.
struct HeadlineStripSkeleton: View {
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 7) {
                        Bar(width: 96, height: 10)
                        Bar(height: 11)
                        Bar(width: 130, height: 11)
                    }
                    .frame(width: 214, alignment: .topLeading)
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(Theme.surface, in: .rect(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .disabled(true)
    }
}

/// Placeholder for an Overview card that is waiting on /insights.
struct InsightCardSkeleton: View {
    let title: String
    var height: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(title)
            RoundedRectangle(cornerRadius: 16).fill(Theme.surface).frame(height: height)
                .opacity(0.6)
        }
    }
}
