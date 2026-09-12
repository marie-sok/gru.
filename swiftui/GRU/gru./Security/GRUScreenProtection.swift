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

/// Screen protection must never participate in the responder chain.
/// The previous implementation wrapped the entire app inside a hidden secure
/// UITextField canvas. On physical devices that could surface the keyboard or
/// leave the hosted SwiftUI tree black during hierarchy rebuilds. We now render
/// SwiftUI normally and redact the UI only while screen capture/mirroring is active.
struct GRUScreenProtectionView<Content: View>: View {
    @StateObject private var model = GRUScreenProtectionModel()
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
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

                        Text("Запись экрана и трансляция отключены для защиты переписки в gru.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                }
                .zIndex(1000)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Защита gru.", isPresented: $model.showScreenshotWarning) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Снимок экрана обнаружен. При записи экрана и трансляции защищённый интерфейс gru. скрывается.")
        }
    }
}
