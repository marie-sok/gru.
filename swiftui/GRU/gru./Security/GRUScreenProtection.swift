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

// MARK: - Telegram-style chat-layer screenshot protection

/// This field is never inserted into the GRU view hierarchy and can never become
/// first responder. It exists only as a UIKit secure-rendering marker, matching
/// Telegram-iOS' layer-level screenshot protection technique.
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

/// Marks an arbitrary CALayer as secure without moving the rendered chat into a
/// UITextField. This mirrors Telegram-iOS' setLayerDisableScreenshots approach:
/// temporarily substitute the target layer for the secure text canvas layer,
/// toggle secureTextEntry, then restore the canvas' original layer.
@MainActor
private enum GRUTelegramLayerScreenshotGuard {
    private static let secureField: GRUChatNonResponderSecureField = {
        let field = GRUChatNonResponderSecureField(
            frame: CGRect(x: 0, y: 0, width: 120, height: 44)
        )
        field.text = " "
        field.textColor = .clear
        field.tintColor = .clear
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.smartInsertDeleteType = .no
        field.textContentType = nil
        field.isUserInteractionEnabled = false
        field.isAccessibilityElement = false
        field.accessibilityElementsHidden = true
        field.inputView = UIView(frame: .zero)
        field.inputAccessoryView = UIView(frame: .zero)
        field.isSecureTextEntry = false
        field.setNeedsLayout()
        field.layoutIfNeeded()
        return field
    }()

    @discardableResult
    static func setProtected(_ targetLayer: CALayer, enabled: Bool) -> Bool {
        let secureField = self.secureField

        secureField.setNeedsLayout()
        secureField.layoutIfNeeded()

        if findSecureCanvas(in: secureField) == nil {
            // Force UIKit to materialize the private secure-text canvas. The
            // field still never joins the app view/responder hierarchy.
            secureField.isSecureTextEntry = true
            secureField.setNeedsLayout()
            secureField.layoutIfNeeded()
        }

        guard let secureView = findSecureCanvas(in: secureField) else {
            return false
        }

        let previousLayer = secureView.layer

        // Telegram-iOS uses the same KVC layer substitution before toggling
        // secureTextEntry. No private selector or class is instantiated here.
        secureView.setValue(targetLayer, forKey: "layer")

        if enabled {
            secureField.isSecureTextEntry = false
            secureField.isSecureTextEntry = true
        } else {
            secureField.isSecureTextEntry = true
            secureField.isSecureTextEntry = false
        }

        secureView.setValue(previousLayer, forKey: "layer")
        return true
    }

    private static func findSecureCanvas(in field: UITextField) -> UIView? {
        // Telegram currently looks for TextLayoutCanvasView among direct
        // UITextField children. Keep that path first and add a recursive
        // compatibility search for UIKit hierarchy changes.
        if let direct = field.subviews.first(where: { view in
            NSStringFromClass(type(of: view))
                .localizedCaseInsensitiveContains("TextLayoutCanvasView")
        }) {
            return direct
        }

        var queue = field.subviews
        while !queue.isEmpty {
            let view = queue.removeFirst()
            let className = NSStringFromClass(type(of: view))

            if className.localizedCaseInsensitiveContains("TextLayoutCanvasView") ||
                className.localizedCaseInsensitiveContains("LayoutCanvasView") {
                return view
            }

            queue.append(contentsOf: view.subviews)
        }

        return nil
    }
}

/// Normal UIKit host for the visible chat. Unlike the previous implementation,
/// the chat is not embedded inside a secure UITextField canvas. Its own CALayer
/// is tagged using the same layer-level secure-rendering trick Telegram uses.
@MainActor
private final class GRUTelegramProtectedChatHostController<Content: View>: UIViewController {
    private let host: UIHostingController<Content>
    private var screenshotProtectionApplied = false
    private var retryWorkItem: DispatchWorkItem?
    private var retryCount = 0

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

        // Fail closed. The privacy cat beneath this controller stays visible
        // until the chat layer itself has been successfully marked protected.
        host.view.isHidden = true

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        host.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyProtectionIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        retryCount = 0
        applyProtectionIfNeeded()
    }

    func update(rootView: Content) {
        host.rootView = rootView
        applyProtectionIfNeeded()
    }

    private func applyProtectionIfNeeded() {
        guard !screenshotProtectionApplied else {
            host.view.isHidden = false
            return
        }

        guard isViewLoaded,
              view.window != nil,
              host.view.bounds.width > 1,
              host.view.bounds.height > 1 else {
            scheduleRetry()
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let protected = GRUTelegramLayerScreenshotGuard.setProtected(
            host.view.layer,
            enabled: true
        )
        CATransaction.commit()

        guard protected else {
            host.view.isHidden = true
            scheduleRetry()
            return
        }

        screenshotProtectionApplied = true
        host.view.isHidden = false
        retryWorkItem?.cancel()
        retryWorkItem = nil
    }

    private func scheduleRetry() {
        guard retryWorkItem == nil, retryCount < 80 else { return }

        retryCount += 1
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.retryWorkItem = nil
            self.applyProtectionIfNeeded()
        }

        retryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }
}

/// Kept under the established GRU type name so the release gate can enforce that
/// screenshot protection remains scoped to authenticated ChatView content only.
private struct GRUChatSecureCaptureContainer<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> GRUTelegramProtectedChatHostController<Content> {
        GRUTelegramProtectedChatHostController(rootView: content)
    }

    func updateUIViewController(
        _ uiViewController: GRUTelegramProtectedChatHostController<Content>,
        context: Context
    ) {
        uiViewController.update(rootView: content)
    }
}

/// Apply only to ChatView. The approved GRU privacy artwork is always rendered
/// underneath the Telegram-style protected chat layer. If the layer cannot be
/// protected, fail closed and leave the privacy artwork visible.
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

/// Root protection deliberately remains public-API-only. The Telegram-style
/// screenshot layer marker is restricted to authenticated ChatView content so it
/// cannot interfere with LocalAuthentication, login, or the app responder chain.
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
