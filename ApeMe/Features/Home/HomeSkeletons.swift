import SwiftUI

/// Placeholders the exact shape of what Explore draws, so the page loads in place rather than
/// rearranging itself once the numbers arrive.

/// The ticker strip: three "SYMBOL ↑ 3.1%" pairs.
struct StripSkeleton: View {
    var body: some View {
        HStack(spacing: 18) {
            ForEach([74, 48, 60], id: \.self) { w in
                HStack(spacing: 6) {
                    Skeleton(height: 12).frame(width: CGFloat(w))
                    Skeleton(height: 22, radius: 11).frame(width: 56)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 12)
    }
}

/// "Recently viewed": a heading and a row of marks with a symbol and a move under each.
struct RecentSkeleton: View {
    var count = 4
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Skeleton(height: 22).frame(width: 150)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(0..<count, id: \.self) { _ in
                        VStack(spacing: 8) {
                            Skeleton(height: 56, radius: 17).frame(width: 56)
                            Skeleton(height: 13).frame(width: 52)
                            Skeleton(height: 12).frame(width: 44)
                        }
                        .frame(width: 76)
                    }
                }
            }
            .scrollDisabled(true).scrollIndicators(.hidden)
        }
    }
}

/// One basket tile: the logo stack, the name, the return and its period.
struct BasketTileSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: -28 * 0.32) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle().fill(Theme.accent.opacity(0.10)).frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                }
            }
            Spacer(minLength: 12)
            Skeleton(height: 15).frame(width: 84)
            Spacer(minLength: 10)
            Skeleton(height: 16).frame(width: 64)
            Skeleton(height: 12).frame(width: 22).padding(.top, 5)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(Theme.surface, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
    }
}

/// The 2×2 baskets grid under its heading, the fourth tile being "See more".
struct BasketsGridSkeleton: View {
    var heading = true
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if heading { Skeleton(height: 22).frame(width: 96) }
            LazyVGrid(columns: [.init(.flexible(), spacing: 10), .init(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in BasketTileSkeleton() }
            }
        }
    }
}

/// One mover card: mark and symbol, the name, the price and its move.
struct MiniCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) { Skeleton(height: 32).frame(width: 32); Skeleton(height: 17).frame(width: 58) }
            Skeleton(height: 14).frame(width: 104)
            VStack(alignment: .leading, spacing: 4) {
                Skeleton(height: 20).frame(width: 78)
                Skeleton(height: 13).frame(width: 52)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
    }
}

/// "Biggest movers today" with its two pills and four cards, then "Most traded" and five rows.
struct MoversSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Skeleton(height: 22).frame(maxWidth: 210)
                Spacer(minLength: 8)
                HStack(spacing: 4) { Skeleton(height: 28, radius: 8).frame(width: 62); Skeleton(height: 28, radius: 8).frame(width: 56) }
            }
            LazyVGrid(columns: [.init(.flexible(), spacing: 10), .init(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in MiniCardSkeleton() }
            }
            Skeleton(height: 22).frame(width: 120).padding(.top, 12)
            VStack(spacing: 0) { ForEach(0..<5, id: \.self) { _ in RowSkeleton(badge: true) } }
        }
    }
}
