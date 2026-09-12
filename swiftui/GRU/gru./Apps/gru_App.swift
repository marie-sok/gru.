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
                releaseTransportGate
            }
            // Runtime locale changes must not recreate RootView. SwiftUI pushes
            // the new locale through the environment while tab/navigation state
            // remains alive.
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

                GRUConnectivityCenter.shared.refresh()

                guard TokenStorage.shared.token != nil else { return }
                GRUConnectivityCenter.shared.reconnectRealtime()
            }
        }
    }

    @ViewBuilder
    private var releaseTransportGate: some View {
        #if DEBUG
        RootView()
        #else
        if isReleaseTransportSafe {
            RootView()
        } else {
            GRUReleaseTransportErrorView()
        }
        #endif
    }

    private var isReleaseTransportSafe: Bool {
        guard
            let httpURL = URL(string: GRUServerConfiguration.httpBaseURL),
            let socketURL = URL(string: GRUServerConfiguration.webSocketURL)
        else {
            return false
        }

        return
            httpURL.scheme?.lowercased() == "https" &&
            httpURL.host?.lowercased() == "gru-edge-v2.onrender.com" &&
            socketURL.scheme?.lowercased() == "wss" &&
            socketURL.host?.lowercased() == "gru-edge-v2.onrender.com" &&
            socketURL.path == "/ws"
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

private struct GRUReleaseTransportErrorView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "network.slash")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(GRUColors.accent)

                Text("gru.")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(GRUL10n.text("Не удалось открыть безопасное подключение GRU."))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(GRUL10n.text("Обновите приложение и попробуйте снова. Ваши данные не отправлялись напрямую в обход защищённого шлюза."))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.60))
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
    }
}
