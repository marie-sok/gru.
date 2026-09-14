import Combine
import SwiftUI
import UIKit

@MainActor
final class GRUScreenProtectionModel: ObservableObject {
    @Published private(set) var isCaptureActive = false
    @Published private(set) var isPrivacyShieldActive = false
    @Published private(set) var showScreenshotWarning = false

    private var observers: [NSObjectProtocol] = []

    init() {
        refreshCaptureState()
        installObservers()
    }

    deinit {
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
                    self?.showScreenshotWarning = true
                    self?.isPrivacyShieldActive = true
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

        if !showScreenshotWarning {
            isPrivacyShieldActive = false
        }
    }

    func dismissScreenshotNotice() {
        showScreenshotWarning = false

        guard !isCaptureActive,
              UIApplication.shared.applicationState == .active else {
            return
        }

        isPrivacyShieldActive = false
    }
}

@MainActor
private final class GRUChatScreenshotLatchModel: ObservableObject {
    @Published private(set) var isLatched = false

    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isLatched = true
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func unlock() {
        guard !UIScreen.main.isCaptured else { return }
        isLatched = false
    }
}

// MARK: - Chat-only still screenshot redaction

/// This is the secure compositor implementation that previously redacted the
/// application on the physical-iPhone beta. The important change is scope:
/// it now exists only inside ChatView, never around RootView/authentication.
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

@MainActor
private struct GRUChatSecureCaptureContainer<Content: View>: UIViewControllerRepresentable {
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
        secureField.textContentType = nil
        secureField.isAccessibilityElement = false
        secureField.accessibilityElementsHidden = true
        secureField.translatesAutoresizingMaskIntoConstraints = false
        secureField.inputView = UIView(frame: .zero)
        secureField.inputAccessoryView = UIView(frame: .zero)

        container.view.addSubview(secureField)
        NSLayoutConstraint.activate([
            secureField.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
            secureField.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
            secureField.topAnchor.constraint(equalTo: container.view.topAnchor),
            secureField.bottomAnchor.constraint(equalTo: container.view.bottomAnchor)
        ])

        // Keep this deliberately identical to the earlier compositor that
        // redacted physical-device captures. Do not replace it with class-name
        // probing or CALayer substitution: those later variants leaked.
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

        #if DEBUG
        print(
            "[GRUPrivacy] proven secure chat compositor mounted: " +
            NSStringFromClass(type(of: protectedCanvas))
        )
        #endif

        return container
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {
        context.coordinator.host.rootView = content

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

struct GRUChatCaptureProtection<Content: View>: View {
    @StateObject private var screenshotLatch = GRUChatScreenshotLatchModel()
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // This layer is intentionally outside the secure compositor.
            // When iOS omits the secure chat surface from capture, the approved
            // GRU privacy artwork is the only layer left in the saved image.
            GRUPrivacyCaptureScene(
                showButton: screenshotLatch.isLatched,
                onDismiss: screenshotLatch.isLatched ? {
                    screenshotLatch.unlock()
                } : nil
            )

            if GRUPrivacyFeatures.chatScreenshotShieldEnabled,
               !screenshotLatch.isLatched {
                GRUChatSecureCaptureContainer {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .privacySensitive()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !GRUPrivacyFeatures.chatScreenshotShieldEnabled,
                      !screenshotLatch.isLatched {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .privacySensitive()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - GRU privacy artwork

struct GRUPrivacyCaptureScene: View {
    var showButton = false
    var onDismiss: (() -> Void)?

    var body: some View {
        GRUPrivacyCaptureArtwork(onDismiss: showButton ? onDismiss : nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }
}

// MARK: - Root recording / switcher protection

/// Root protection intentionally stays on public lifecycle/capture APIs only.
/// It must not use the secure UITextField compositor because doing so previously
/// interfered with Face ID, startup focus and keyboard behaviour.
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
                GRUPrivacyCaptureScene(
                    showButton: model.showScreenshotWarning && !model.isCaptureActive,
                    onDismiss: model.showScreenshotWarning ? {
                        model.dismissScreenshotNotice()
                    } : nil
                )
                .zIndex(10_000)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.12), value: model.shouldRedact)
    }
}
