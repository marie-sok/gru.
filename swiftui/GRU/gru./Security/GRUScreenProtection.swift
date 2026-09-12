import Combine
import SwiftUI
import UIKit

@MainActor
final class GRUScreenProtectionModel: ObservableObject {
    @Published private(set) var isCaptureActive = false
    @Published private(set) var isPrivacyShieldActive = false
    @Published var showScreenshotWarning = false

    private var observers: [NSObjectProtocol] = []
    private var screenshotShieldTask: Task<Void, Never>?

    init() {
        refreshCaptureState()
        installObservers()
    }

    deinit {
        screenshotShieldTask?.cancel()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    var shouldRedact: Bool {
        isCaptureActive || isPrivacyShieldActive
    }

    private func installObservers() {
        let center = NotificationCenter.default

        observers.append(
            center.addObserver(
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
            center.addObserver(
                forName: UIApplication.userDidTakeScreenshotNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleScreenshotDetected()
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isPrivacyShieldActive = true
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isPrivacyShieldActive = true
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleDidBecomeActive()
                }
            }
        )
    }

    private func refreshCaptureState() {
        isCaptureActive = UIScreen.main.isCaptured
        if isCaptureActive {
            isPrivacyShieldActive = true
        }
    }

    private func handleDidBecomeActive() {
        refreshCaptureState()

        guard !isCaptureActive else {
            isPrivacyShieldActive = true
            return
        }

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !self.isCaptureActive else { return }
            self.isPrivacyShieldActive = false
        }
    }

    private func handleScreenshotDetected() {
        isPrivacyShieldActive = true
        showScreenshotWarning = true

        screenshotShieldTask?.cancel()
        screenshotShieldTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.25))
            guard let self, !Task.isCancelled else { return }
            guard !self.isCaptureActive,
                  UIApplication.shared.applicationState == .active
            else {
                return
            }
            self.isPrivacyShieldActive = false
        }
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
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .privacySensitive()

            if model.shouldRedact {
                privacyShield
                    .zIndex(10_000)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.12), value: model.shouldRedact)
        .alert(GRUL10n.text("Защита gru."), isPresented: $model.showScreenshotWarning) {
            Button(GRUL10n.text("Понятно"), role: .cancel) {}
        } message: {
            Text(
                GRUL10n.text(
                    "Снимок экрана обнаружен. iOS не позволяет приложению отменить одиночный системный скриншот заранее."
                )
            )
        }
    }

    private var privacyShield: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(GRUColors.accent)

                Text(GRUL10n.text("Контент защищён"))
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text(
                    GRUL10n.text(
                        model.isCaptureActive
                        ? "Запись экрана и трансляция скрыты для защиты переписки в gru."
                        : "GRU скрывает содержимое, пока приложение не активно."
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
            }
            .padding(28)
        }
        .allowsHitTesting(true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(GRUL10n.text("Контент защищён"))
    }
}
