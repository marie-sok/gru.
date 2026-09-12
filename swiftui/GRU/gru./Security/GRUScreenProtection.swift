import Combine
import SwiftUI
import UIKit

@MainActor
final class GRUScreenProtectionModel: ObservableObject {
    @Published private(set) var isCaptureActive = false
    @Published private(set) var isPrivacyShieldActive = false
    @Published private(set) var showScreenshotWarning = false

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
            if !self.showScreenshotWarning {
                self.isPrivacyShieldActive = false
            }
        }
    }

    private func handleScreenshotDetected() {
        showScreenshotWarning = true
        isPrivacyShieldActive = true

        screenshotShieldTask?.cancel()
        screenshotShieldTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3.2))
            guard let self, !Task.isCancelled else { return }
            self.dismissScreenshotNotice()
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

// MARK: - Chat-only still screenshot protection

/// Exists only inside an authenticated ChatView. It must never wrap RootView,
/// LoginView or the LocalAuthentication lifecycle.
private final class GRUChatNonResponderSecureField: UITextField {
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

/// Best-effort still-capture compositor scoped to ChatView only.
///
/// The approved GRU privacy artwork is a normal layer underneath this host.
/// The visible chat is mounted into the secure text canvas. On iOS versions
/// where that secure canvas is omitted from a still capture, the saved image
/// contains the privacy artwork rather than the conversation.
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

        let secureField = GRUChatNonResponderSecureField(frame: .zero)
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
        secureField.clipsToBounds = true
        secureField.translatesAutoresizingMaskIntoConstraints = false

        // Belt-and-suspenders: even if UIKit asks for an input surface, this
        // non-responder field has no keyboard to show.
        secureField.inputView = UIView(frame: .zero)
        secureField.inputAccessoryView = UIView(frame: .zero)

        container.view.addSubview(secureField)
        NSLayoutConstraint.activate([
            secureField.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
            secureField.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
            secureField.topAnchor.constraint(equalTo: container.view.topAnchor),
            secureField.bottomAnchor.constraint(equalTo: container.view.bottomAnchor)
        ])

        // Force UIKit to build the secure-text hierarchy before we look for
        // its rendering canvas. The previous beta grabbed subviews.first before
        // layout, which is not stable across iOS builds.
        container.view.layoutIfNeeded()
        secureField.isSecureTextEntry = false
        secureField.layoutIfNeeded()
        secureField.isSecureTextEntry = true
        secureField.setNeedsLayout()
        secureField.layoutIfNeeded()
        container.view.layoutIfNeeded()

        let host = context.coordinator.host
        host.view.backgroundColor = .clear
        host.view.insetsLayoutMarginsFromSafeArea = false
        host.additionalSafeAreaInsets = .zero

        guard let protectedCanvas = Self.findSecureCanvas(in: secureField) else {
            // If Apple changes the internal hierarchy, preserve a usable chat
            // instead of producing a broken/black interface.
            mount(host: host, in: container.view, parent: container)
            context.coordinator.secureField = secureField
            context.coordinator.didFindSecureCanvas = false
            return container
        }

        protectedCanvas.isUserInteractionEnabled = true
        protectedCanvas.insetsLayoutMarginsFromSafeArea = false
        protectedCanvas.backgroundColor = .clear

        mount(host: host, in: protectedCanvas, parent: container)

        context.coordinator.secureField = secureField
        context.coordinator.protectedCanvas = protectedCanvas
        context.coordinator.didFindSecureCanvas = true
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

    private static func mount(
        host: UIHostingController<Content>,
        in target: UIView,
        parent: UIViewController
    ) {
        parent.addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        target.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: target.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: target.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: target.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: target.bottomAnchor)
        ])

        host.didMove(toParent: parent)
    }

    private static func findSecureCanvas(in field: UITextField) -> UIView? {
        let descendants = allDescendants(of: field)

        // Current iOS secure text fields normally expose a UIKit canvas whose
        // private class name contains "Canvas". We do not instantiate or call a
        // private API; the name is used only to avoid assuming subviews.first.
        if let canvas = descendants.first(where: { view in
            NSStringFromClass(type(of: view))
                .localizedCaseInsensitiveContains("Canvas")
        }) {
            return canvas
        }

        // Compatibility fallback for older builds where the first child was
        // the protected render surface.
        return field.subviews.first
    }

    private static func allDescendants(of root: UIView) -> [UIView] {
        var result: [UIView] = []
        var queue = root.subviews

        while !queue.isEmpty {
            let view = queue.removeFirst()
            result.append(view)
            queue.append(contentsOf: view.subviews)
        }

        return result
    }

    final class Coordinator {
        let host: UIHostingController<Content>
        weak var secureField: GRUChatNonResponderSecureField?
        weak var protectedCanvas: UIView?
        var didFindSecureCanvas = false

        init(rootView: Content) {
            host = UIHostingController(rootView: rootView)
            host.view.backgroundColor = .clear
        }
    }
}

/// Apply only to ChatView. The approved image is always pre-rendered behind the
/// secure chat, mirroring the old black-screen approach without touching auth.
struct GRUChatCaptureProtection<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if GRUPrivacyFeatures.chatScreenshotShieldEnabled {
            ZStack {
                GRUPrivacyCaptureScene(showButton: false, onDismiss: nil)

                GRUChatSecureCaptureContainer {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .privacySensitive()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .privacySensitive()
        }
    }
}

// MARK: - Approved GRU privacy artwork

/// Kept under the historic type name because the release audit verifies that
/// the replacement scene remains wired into both capture paths.
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

/// Public-API privacy layer for recording/mirroring and app-switcher snapshots.
/// It deliberately does not use the secure UITextField compositor; only the
/// authenticated ChatView is allowed to use that best-effort still-capture path.
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
