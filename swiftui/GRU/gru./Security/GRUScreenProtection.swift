import Combine
import SwiftUI
import UIKit

@_silgen_name("GRUSetLayerDisableScreenshots")
private func GRUSetLayerDisableScreenshotsRuntime(
    _ layer: UnsafeMutableRawPointer,
    _ disableScreenshots: Bool
) -> Bool

@MainActor
private enum GRUSecureLayerBridge {
    @discardableResult
    static func setProtected(_ layer: CALayer, enabled: Bool) -> Bool {
        GRUSetLayerDisableScreenshotsRuntime(
            Unmanaged.passUnretained(layer).toOpaque(),
            enabled
        )
    }
}

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

private final class GRUSecureTextFieldDelegate: NSObject, UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        false
    }
}

// MARK: - Chat-only still screenshot protection

/// The complete ChatView is rendered inside UIKit secure-text rendering and the
/// whole UIKit controller layer is also marked capture-protected. Privacy art is
/// outside this controller, so an omitted secure surface reveals only that art.
@MainActor
private final class GRUChatSecureHostController<Content: View>: UIViewController {
    private let secureField = UITextField(frame: .zero)
    private let secureFieldDelegate = GRUSecureTextFieldDelegate()
    private let host: UIHostingController<Content>

    private weak var protectedCanvas: UIView?
    private var hostConstraints: [NSLayoutConstraint] = []
    private var retryWorkItem: DispatchWorkItem?
    private var retryCount = 0
    private var didPrimeSecureField = false
    private var didLogHierarchy = false
    private var protectedLayers: [CALayer] = []

    init(rootView: Content) {
        host = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)

        host.view.backgroundColor = .clear
        host.view.insetsLayoutMarginsFromSafeArea = false
        host.additionalSafeAreaInsets = .zero
        host.view.isHidden = true
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

        secureField.delegate = secureFieldDelegate
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
        secureField.isHidden = false
        secureField.alpha = 1
        secureField.translatesAutoresizingMaskIntoConstraints = false
        secureField.inputView = UIView(frame: .zero)
        secureField.inputAccessoryView = UIView(frame: .zero)
        secureField.isSecureTextEntry = false

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
        installSecureSurfaceIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        retryCount = 0
        installSecureSurfaceIfNeeded()
    }

    func update(rootView: Content) {
        host.rootView = rootView
        if secureField.isFirstResponder {
            secureField.resignFirstResponder()
        }
        installSecureSurfaceIfNeeded()
    }

    func disableProtection() {
        retryWorkItem?.cancel()
        retryWorkItem = nil
        host.view.isHidden = true

        for layer in protectedLayers.reversed() {
            _ = GRUSecureLayerBridge.setProtected(layer, enabled: false)
        }
        protectedLayers.removeAll()
    }

    private func installSecureSurfaceIfNeeded() {
        guard isViewLoaded,
              view.window != nil,
              view.bounds.width > 1,
              view.bounds.height > 1 else {
            failClosedAndRetry()
            return
        }

        host.view.isHidden = true
        primeSecureFieldIfNeeded()
        enableInteractionRecursively(secureField)

        guard var canvas = Self.findSecureCanvas(in: secureField) else {
            logHierarchyOnce(reason: "secure canvas not found")
            failClosedAndRetry()
            return
        }

        if host.view.superview !== canvas {
            mountHost(in: canvas)
        }

        // UIKit can replace its internal secure canvas when secureTextEntry is
        // toggled. Stabilize the canvas after the real chat has been mounted.
        for _ in 0..<3 {
            rearmSecureTextRendering()

            guard let current = Self.findSecureCanvas(in: secureField) else {
                logHierarchyOnce(reason: "secure canvas disappeared during rearm")
                failClosedAndRetry()
                return
            }

            if current !== canvas || host.view.superview !== current {
                mountHost(in: current)
                canvas = current
                continue
            }

            break
        }

        protectedCanvas = canvas
        enableInteractionRecursively(secureField)

        guard secureField.isSecureTextEntry,
              canvas.isDescendant(of: secureField),
              host.view.superview === canvas else {
            failClosedAndRetry()
            return
        }

        guard protectCompleteChatSurface(canvas: canvas) else {
            logHierarchyOnce(reason: "secure layer protection failed")
            failClosedAndRetry()
            return
        }

        host.view.isHidden = false
        retryWorkItem?.cancel()
        retryWorkItem = nil

        #if DEBUG
        print("[GRUPrivacy] plain UITextField secure canvas: \(NSStringFromClass(type(of: canvas)))")
        print("[GRUPrivacy] complete chat controller protected")
        #endif
    }

    private func protectCompleteChatSurface(canvas: UIView) -> Bool {
        for layer in protectedLayers.reversed() {
            _ = GRUSecureLayerBridge.setProtected(layer, enabled: false)
        }
        protectedLayers.removeAll()

        // Protect from the outside in. If iOS honors any one of these secure
        // surfaces, no conversation pixels should survive in the saved capture.
        let layers = [
            view.layer,
            secureField.layer,
            canvas.layer,
            host.view.layer
        ]

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var success = true
        for layer in layers {
            let protected = GRUSecureLayerBridge.setProtected(layer, enabled: true)
            success = success && protected
            if protected {
                protectedLayers.append(layer)
            }
        }

        CATransaction.commit()
        return success
    }

    private func primeSecureFieldIfNeeded() {
        guard !didPrimeSecureField else {
            secureField.setNeedsLayout()
            secureField.layoutIfNeeded()
            return
        }

        secureField.isSecureTextEntry = false
        secureField.setNeedsLayout()
        secureField.layoutIfNeeded()
        secureField.isSecureTextEntry = true
        secureField.setNeedsLayout()
        secureField.layoutIfNeeded()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        didPrimeSecureField = true
    }

    private func rearmSecureTextRendering() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        secureField.isSecureTextEntry = false
        secureField.setNeedsLayout()
        secureField.layoutIfNeeded()
        secureField.isSecureTextEntry = true
        secureField.setNeedsLayout()
        secureField.layoutIfNeeded()
        CATransaction.commit()

        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func mountHost(in canvas: UIView) {
        canvas.backgroundColor = .clear
        canvas.clipsToBounds = true
        enableInteractionRecursively(secureField)

        let needsChildAttach = host.parent == nil
        if needsChildAttach {
            addChild(host)
        }

        NSLayoutConstraint.deactivate(hostConstraints)
        hostConstraints.removeAll()
        host.view.removeFromSuperview()
        host.view.isHidden = true
        host.view.translatesAutoresizingMaskIntoConstraints = false

        canvas.addSubview(host.view)
        hostConstraints = [
            host.view.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: canvas.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: canvas.bottomAnchor)
        ]
        NSLayoutConstraint.activate(hostConstraints)

        canvas.setNeedsLayout()
        canvas.layoutIfNeeded()

        if needsChildAttach {
            host.didMove(toParent: self)
        }
    }

    private func enableInteractionRecursively(_ root: UIView) {
        root.isUserInteractionEnabled = true
        for child in root.subviews {
            enableInteractionRecursively(child)
        }
    }

    private func failClosedAndRetry() {
        host.view.isHidden = true
        scheduleRetry()
    }

    private func scheduleRetry() {
        guard retryWorkItem == nil, retryCount < 240 else { return }

        retryCount += 1
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.retryWorkItem = nil
            self.installSecureSurfaceIfNeeded()
        }

        retryWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.05,
            execute: work
        )
    }

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
            "TextEffectsView",
            "TextFieldCanvasView"
        ]

        for token in strictTokens {
            if let match = descendants.first(where: { candidate in
                NSStringFromClass(type(of: candidate))
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
        print(
            "[GRUPrivacy] \(indent)\(className) " +
            "frame=\(root.frame.integral) bounds=\(root.bounds.integral) " +
            "hidden=\(root.isHidden) alpha=\(root.alpha)"
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

    static func dismantleUIViewController(
        _ uiViewController: GRUChatSecureHostController<Content>,
        coordinator: ()
    ) {
        uiViewController.disableProtection()
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
