import SwiftUI

@main
struct Stonks247App: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                // nil follows the phone; Settings can pin light or dark.
                .preferredColorScheme(app.colorScheme)
        }
    }
}
