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

/// Hosts the conversation inside UIKit's actual secure-text rendering canvas.
/// The privacy artwork is rendered behind this controller, so a compositor that
/// omits secure text content reveals the GRU privacy scene instead of messages.
///
/// Important: there is deliberately no ordinary UIView fallback. If a future
/// iOS version changes the secure canvas internals, the chat fails closed and
/// the privacy artwork remains visible rather than exposing the conversation.
@MainActor
private final class GRUChatSecureHostController<Content: View>: UIViewController {
    private let secureField = GRUChatNonResponderSecureField(frame: .zero)
    private let host: UIHostingController<Content>

    private weak var protectedCanvas: UIView?
    private var hostConstraints: [NSLayoutConstraint] = []
    private var retryWorkItem: DispatchWorkItem?
    private var retryCount = 0
    private var didPrimeSecureField = false
    private var didLogHierarchy = false

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
        secureField.isUserInteractionEnabled = true
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

        primeSecureFieldIfNeeded()

        guard let canvas = Self.findSecureCanvas(in: secureField) else {
            logHierarchyOnce(reason: "secure canvas not found")
            scheduleRetry()
            return
        }

        mountHost(in: canvas)
        protectedCanvas = canvas
        retryWorkItem?.cancel()
        retryWorkItem = nil

        #if DEBUG
        print("[GRUPrivacy] secure canvas mounted: \(NSStringFromClass(type(of: canvas)))")
        #endif
    }

    private func primeSecureFieldIfNeeded() {
        if !didPrimeSecureField {
            // The field must already be attached to a real window before this
            // toggle so UIKit creates its secure rendering subtree for this OS.
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
    }

    private func mountHost(in canvas: UIView) {
        canvas.isUserInteractionEnabled = true
        canvas.insetsLayoutMarginsFromSafeArea = false
        canvas.backgroundColor = .clear
        canvas.clipsToBounds = true

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
        guard retryWorkItem == nil, retryCount < 120 else { return }

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

    /// Restrict matching to known UITextField layout-canvas families. A generic
    /// "Canvas" match is unsafe because unrelated UIKit/SwiftUI views can carry
    /// that token and are not screenshot-protected.
    private static func findSecureCanvas(in field: UITextField) -> UIView? {
        let descendants = allDescendants(of: field)

        let exactNames = [
            "_UITextLayoutCanvasView",
            "UITextLayoutCanvasView",
            "_UITextFieldCanvasView",
            "UITextFieldCanvasView"
        ]

        for name in exactNames {
            if let match = descendants.first(where: {
                NSStringFromClass(type(of: $0)) == name
            }) {
                return match
            }
        }

        let strictTokens = [
            "TextLayoutCanvasView",
            "TextFieldCanvasView"
        ]

        for token in strictTokens {
            if let match = descendants.first(where: { candidate in
                let className = NSStringFromClass(type(of: candidate))
                return className.localizedCaseInsensitiveContains(token)
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
            let candidate = queue.removeFirst()
            result.append(candidate)
            queue.append(contentsOf: candidate.subviews)
        }

        return result
    }

    private func logHierarchyOnce(reason: String) {
        #if DEBUG
        guard !didLogHierarchy else { return }
        didLogHierarchy = true

        print("[GRUPrivacy] secure-field hierarchy: \(reason)")
        Self.logHierarchy(of: secureField, depth: 0)
        #endif
    }

    #if DEBUG
    private static func logHierarchy(of root: UIView, depth: Int) {
        let indent = String(repeating: "  ", count: depth)
        let className = NSStringFromClass(type(of: root))
        let frame = root.frame.integral
        let bounds = root.bounds.integral
        print(
            "[GRUPrivacy] \(indent)\(className) " +
            "frame=\(frame) bounds=\(bounds) " +
            "hidden=\(root.isHidden) alpha=\(String(format: \"%.2f\", root.alpha))"
        )

        for child in root.subviews {
            logHierarchy(of: child, depth: depth + 1)
        }
    }
    #endif
}

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
