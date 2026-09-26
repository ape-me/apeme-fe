import SwiftUI

@main
struct Stonks247App: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .preferredColorScheme(.dark)
        }
    }
}
