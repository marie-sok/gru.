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

/// UITextField is used only as an iOS secure-rendering host.
/// It must never enter the responder chain, request focus, or summon a keyboard.
private final class GRUNonResponderSecureField: UITextField {
    override var canBecomeFirstResponder: Bool { false }

    override func becomeFirstResponder() -> Bool {
        false
    }

    override func canPerformAction(
        _ action: Selector,
        withSender sender: Any?
    ) -> Bool {
        false
    }
}

/// Best-effort still-screenshot redaction for the physical beta.
///
/// iOS has no public API that lets a normal app cancel a still screenshot.
/// This container instead places the rendered SwiftUI hierarchy inside the
/// secure-text compositor path so captured still images are redacted on iOS
/// versions where that compositor behaviour is available.
///
/// Unlike the previous implementation, the secure field is permanently
/// non-responder and has no usable input view, preventing it from stealing
/// focus or raising the keyboard.
private struct GRUSecureCaptureContainer<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(rootView: content)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let container = UIViewController()
        container.view.backgroundColor = .clear
        container.view.insetsLayoutMarginsFromSafeArea = false
        container.additionalSafeAreaInsets = .zero

        let secureField = GRUNonResponderSecureField(frame: .zero)
        secureField.isSecureTextEntry = true
        secureField.text = " "
        secureField.textColor = .clear
        secureField.tintColor = .clear
        secureField.backgroundColor = .clear
        secureField.borderStyle = .none
        secureField.autocorrectionType = .no
        secureField.spellCheckingType = .no
        secureField.smartDashesType = .no
        secureField.smartQuotesType = .no
        secureField.smartInsertDeleteType = .no
        secureField.accessibilityElementsHidden = true
        secureField.translatesAutoresizingMaskIntoConstraints = false

        // Even if UIKit asks this internal host for input, there is no keyboard.
        secureField.inputView = UIView(frame: .zero)
        secureField.inputAccessoryView = UIView(frame: .zero)

        container.view.addSubview(secureField)
        NSLayoutConstraint.activate([
            secureField.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
            secureField.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
            secureField.topAnchor.constraint(equalTo: container.view.topAnchor),
            secureField.bottomAnchor.constraint(equalTo: container.view.bottomAnchor)
        ])

        // Secure text entry owns an internal render canvas. Hosting inside that
        // canvas keeps the visible SwiftUI hierarchy interactive while allowing
        // the secure compositor to redact still capture on supported iOS builds.
        let protectedCanvas = secureField.subviews.first ?? secureField
        protectedCanvas.isUserInteractionEnabled = true
        protectedCanvas.insetsLayoutMarginsFromSafeArea = false
        protectedCanvas.backgroundColor = .clear

        let host = context.coordinator.host
        host.view.backgroundColor = .clear
        host.view.insetsLayoutMarginsFromSafeArea = false
        host.additionalSafeAreaInsets = .zero

        container.addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        protectedCanvas.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: protectedCanvas.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: protectedCanvas.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: protectedCanvas.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: protectedCanvas.bottomAnchor)
        ])

        host.didMove(toParent: container)

        context.coordinator.secureField = secureField
        context.coordinator.protectedCanvas = protectedCanvas
        return container
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {
        context.coordinator.host.rootView = content

        // Defensive: a secure host must never retain first-responder state.
        if context.coordinator.secureField?.isFirstResponder == true {
            context.coordinator.secureField?.resignFirstResponder()
        }
    }

    static func dismantleUIViewController(
        _ uiViewController: UIViewController,
        coordinator: Coordinator
    ) {
        if coordinator.secureField?.isFirstResponder == true {
            coordinator.secureField?.resignFirstResponder()
        }
        coordinator.host.willMove(toParent: nil)
        coordinator.host.view.removeFromSuperview()
        coordinator.host.removeFromParent()
    }

    final class Coordinator {
        let host: UIHostingController<Content>
        weak var secureField: GRUNonResponderSecureField?
        weak var protectedCanvas: UIView?

        init(rootView: Content) {
            host = UIHostingController(rootView: rootView)
            host.view.backgroundColor = .clear
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
            GRUSecureCaptureContainer {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .privacySensitive()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if model.shouldRedact {
                privacyShield
                    .zIndex(10_000)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.12), value: model.shouldRedact)
        .alert("Защита gru.", isPresented: $model.showScreenshotWarning) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Снимок экрана обнаружен. Защищённый интерфейс GRU скрывается от захвата там, где это поддерживает iOS.")
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
