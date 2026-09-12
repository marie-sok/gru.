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

/// Owns the chat-only secure compositor. The conversation is never mounted into
/// an ordinary UIView fallback: until UIKit exposes a verified secure text
/// canvas, the SwiftUI privacy artwork behind this controller remains visible.
private final class GRUChatSecureHostController<Content: View>: UIViewController {
    private let secureField = GRUChatNonResponderSecureField(frame: .zero)
    private let host: UIHostingController<Content>

    private weak var protectedCanvas: UIView?
    private var hostConstraints: [NSLayoutConstraint] = []
    private var retryWorkItem: DispatchWorkItem?
    private var retryCount = 0
    private var didPrimeSecureField = false

    init(rootView: Content) {
        host = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)

        host.view.backgroundColor = .clear
        host.view.insetsLayoutMarginsFromSafeArea = false
        host.additionalSafeAreaInsets = .zero
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        retryWorkItem?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.insetsLayoutMarginsFromSafeArea = false
        additionalSafeAreaInsets = .zero

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
        secureField.accessibilityElementsHidden = false
        secureField.clipsToBounds = true
        secureField.translatesAutoresizingMaskIntoConstraints = false
        secureField.inputView = UIView(frame: .zero)
        secureField.inputAccessoryView = UIView(frame: .zero)
        secureField.isSecureTextEntry = true

        view.addSubview(secureField)
        NSLayoutConstraint.activate([
            secureField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            secureField.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            secureField.topAnchor.constraint(equalTo: view.topAnchor),
            secureField.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        installSecureCanvasIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        retryCount = 0
        installSecureCanvasIfNeeded()
    }

    func update(rootView: Content) {
        host.rootView = rootView

        if secureField.isFirstResponder {
            secureField.resignFirstResponder()
        }

        installSecureCanvasIfNeeded()
    }

    private func installSecureCanvasIfNeeded() {
        guard isViewLoaded,
              view.window != nil,
              view.bounds.width > 1,
              view.bounds.height > 1 else {
            scheduleRetry()
            return
        }

        if let protectedCanvas,
           protectedCanvas.isDescendant(of: secureField),
           host.view.superview === protectedCanvas {
            retryWorkItem?.cancel()
            retryWorkItem = nil
            return
        }

        if !didPrimeSecureField {
            secureField.isSecureTextEntry = false
            secureField.layoutIfNeeded()
            secureField.isSecureTextEntry = true
            secureField.setNeedsLayout()
            secureField.layoutIfNeeded()
            didPrimeSecureField = true
        } else {
            secureField.setNeedsLayout()
            secureField.layoutIfNeeded()
        }

        guard let canvas = Self.findSecureCanvas(in: secureField) else {
            // Fail closed. Never expose the chat through an ordinary UIView.
            scheduleRetry()
            return
        }

        mountHost(in: canvas)
        protectedCanvas = canvas
        retryWorkItem?.cancel()
        retryWorkItem = nil
    }

    private func mountHost(in canvas: UIView) {
        canvas.isUserInteractionEnabled = true
        canvas.insetsLayoutMarginsFromSafeArea = false
        canvas.backgroundColor = .clear

        let needsChildAttach = host.parent == nil
        if needsChildAttach {
            addChild(host)
        }

        NSLayoutConstraint.deactivate(hostConstraints)
        hostConstraints.removeAll()
        host.view.removeFromSuperview()

        host.view.translatesAutoresizingMaskIntoConstraints = false
        canvas.addSubview(host.view)

        hostConstraints = [
            host.view.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: canvas.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: canvas.bottomAnchor)
        ]
        NSLayoutConstraint.activate(hostConstraints)

        if needsChildAttach {
            host.didMove(toParent: self)
        }
    }

    private func scheduleRetry() {
        guard retryWorkItem == nil, retryCount < 60 else { return }

        retryCount += 1
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.retryWorkItem = nil
            self.installSecureCanvasIfNeeded()
        }

        retryWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.05,
            execute: work
        )
    }

    private static func findSecureCanvas(in field: UITextField) -> UIView? {
        let descendants = allDescendants(of: field)
        let priorities = [
            "LayoutCanvasView",
            "CanvasView",
            "Canvas"
        ]

        for token in priorities {
            if let match = descendants.first(where: { view in
                NSStringFromClass(type(of: view))
                    .localizedCaseInsensitiveContains(token)
            }) {
                return match
            }
        }

        return nil
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
}

/// Best-effort still-capture compositor scoped to ChatView only. The content is
/// fail-closed: no verified secure text canvas means no conversation rendering.
private struct GRUChatSecureCaptureContainer<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> GRUChatSecureHostController<Content> {
        GRUChatSecureHostController(rootView: content)
    }

    func updateUIViewController(
        _ uiViewController: GRUChatSecureHostController<Content>,
        context: Context
    ) {
        uiViewController.update(rootView: content)
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
