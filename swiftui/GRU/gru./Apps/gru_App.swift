import SwiftUI

@main
struct gru_App: App {
    @Environment(\.scenePhase) private var scenePhase

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
            // GRUL10n is intentionally runtime-switchable. Rebuilding the root
            // prevents already-pushed Settings screens from retaining strings
            // evaluated with the previous language.
            .id(languageRaw)
            .environment(
                \.locale,
                appLanguage.locale
            )
            .task {
                GRURadioHandoffMonitor.shared.start()
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
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }

                // A URLSessionWebSocketTask may look connected after iOS has
                // suspended the app or changed radios while it was backgrounded.
                // Refresh backend readiness and deliberately establish a fresh
                // STOMP session whenever an authenticated app returns active.
                GRUConnectivityCenter.shared.refresh()

                guard TokenStorage.shared.token != nil else { return }
                GRUConnectivityCenter.shared.reconnectRealtime()
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
