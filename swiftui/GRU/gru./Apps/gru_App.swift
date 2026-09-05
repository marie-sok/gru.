import SwiftUI

@main
struct gru_App: App {
    init() {
        GRUThemePolicy.migrateIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            GRUScreenProtectionView {
                RootView()
            }
        }
    }
}
