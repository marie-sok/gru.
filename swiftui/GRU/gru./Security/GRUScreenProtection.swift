import Combine
import SwiftUI
import UIKit

@MainActor
final class GRUScreenProtectionModel: ObservableObject {
    @Published private(set) var isCaptureActive = false
    @Published var showScreenshotWarning = false

    private var observers: [NSObjectProtocol] = []

    init() {
        refreshCaptureState()

        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIScreen.capturedDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshCaptureState()
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.userDidTakeScreenshotNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.showScreenshotWarning = true
                }
            }
        )
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func refreshCaptureState() {
        isCaptureActive = UIScreen.main.isCaptured
    }
}


struct GRUScreenProtectionView<Content: View>: View {
    @StateObject private var model = GRUScreenProtectionModel()
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Keep SwiftUI's native focus, safe-area and scene environment.
            // Never put the app inside a password field's private subviews.
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if model.isCaptureActive {
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 14) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(GRUColors.accent)

                        Text("Контент защищён")
                            .font(.title3.bold())
                            .foregroundStyle(.white)

                        Text("gru. скрывает содержимое во время записи экрана или трансляции.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                }
                .zIndex(1000)
            }
        }
        .alert("Защита gru.", isPresented: $model.showScreenshotWarning) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Снимок экрана сделан. На нём может быть видна переписка. gru. скрывает содержимое при записи экрана и трансляции, но не блокирует обычные снимки.")
        }
    }
}
