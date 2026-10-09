import SwiftUI

/// The basket's cover: the top of the screen, edge to edge, in the app's blue. The stocks in
/// it, its name and tagline, and whatever number the screen is about. The same block opens the
/// basket page, both sheets and the position page, so a basket looks like itself everywhere.
///
/// `bar` is the row that sits in the cover's top band: a sheet's title and close button. Pages
/// leave it empty and pin their back button over the band instead, so it is still there once
/// the cover has scrolled away.
struct BasketCover<Bar: View, Trailing: View>: View {
    let name: String
    var tagline: String? = nil
    let logos: [URL]
    @ViewBuilder let bar: Bar
    @ViewBuilder let trailing: Trailing

    init(name: String, tagline: String? = nil, logos: [URL],
         @ViewBuilder bar: () -> Bar = { EmptyView() }, @ViewBuilder trailing: () -> Trailing) {
        self.name = name; self.tagline = tagline; self.logos = logos
        self.bar = bar(); self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // An EmptyView takes no space whatever frame it is given, so the band is a real
            // 56pt of colour and the bar sits in it.
            ZStack(alignment: .leading) {
                Color.clear.frame(height: 56)
                bar.padding(.horizontal, 12)
            }
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    LogoStack(urls: logos, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).font(.system(size: 22, weight: .semibold)).tracking(-0.5).foregroundStyle(Theme.ink)
                        if let tagline {
                            Text(tagline).font(.sub).foregroundStyle(Theme.muted).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Spacer(minLength: 12)
                trailing
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BasketTint.gradient)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

/// The cover's blue: the accent, washed to a tint that ink and the green and red numbers sit
/// on comfortably. One colour for every basket; the logos tell them apart.
enum BasketTint {
    static var gradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xD6E4FF), Color(hex: 0xEEF4FF)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
