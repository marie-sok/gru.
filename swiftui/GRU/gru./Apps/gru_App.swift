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
            .task {
                await publishE2EEIdentityIfAuthenticated()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .gruSessionDidAuthenticate
                )
            ) { _ in
                Task {
                    await publishE2EEIdentityIfAuthenticated()
                }
            }
        }
    }

    @MainActor
    private func publishE2EEIdentityIfAuthenticated() async {
        guard let token = TokenStorage.shared.token,
              !token.isEmpty else {
            return
        }

        do {
            _ = try await E2EEAPIService.shared.publishIdentity(token: token)
        } catch {
            #if DEBUG
            print("E2EE identity publish skipped/failed:", error.localizedDescription)
            #endif
        }
    }
}
