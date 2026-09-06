import SwiftUI

@main
struct gru_App: App {
    @AppStorage(GRUAppLanguage.storageKey)
    private var languageRaw =
        GRUAppLanguage.defaultLanguage.rawValue

    private var appLanguage: GRUAppLanguage {
        GRUAppLanguage(rawValue: languageRaw)
            ?? .defaultLanguage
    }

    init() {
        GRUThemePolicy.migrateIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            GRUScreenProtectionView {
                RootView()
            }
            .environment(
                \.locale,
                appLanguage.locale
            )
        }
    }
}
