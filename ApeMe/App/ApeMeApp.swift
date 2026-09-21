import SwiftUI

@main
struct ApeMeApp: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(\.skin, Skin(mode: app.mode ?? .invest))
                .preferredColorScheme(.dark)
        }
    }
}
