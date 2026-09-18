import SwiftUI

@main
struct ApeMeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.green)
        }
    }
}

enum Route: Hashable {
    case floor(Stock)
    case token(String)
}

struct RootView: View {
    var body: some View {
        NavigationStack {
            StocksView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .floor(let stock): FloorView(stock: stock)
                    case .token(let mint): TokenView(mint: mint)
                    }
                }
        }
        .background(Theme.bg)
    }
}
