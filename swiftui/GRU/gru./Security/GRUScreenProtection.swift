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

// MARK: - Chat-only still screenshot protection

/// A non-interactive secure text field supplies iOS' protected rendering
/// surface. It never becomes first responder and therefore cannot steal focus
/// from the real chat input or summon a keyboard.
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

/// Owns the protected chat hierarchy. The real chat is deliberately left
/// unattached until UITextField has created its secure internal canvas.
/// If that canvas never appears, the controller fails closed: the privacy
/// artwork underneath remains visible and conversation pixels are never mounted
/// into an unprotected fallback view.
@MainActor
private final class GRUProtectedChatController<Content: View>: UIViewController {
    private let secureField = GRUNonResponderSecureField(frame: .zero)
    private let host: UIHostingController<Content>

    private weak var protectedCanvas: UIView?
    private var didMountProtectedContent = false
    private var retryScheduled = false
    private var retryCount = 0
    private let maxRetryCount = 120

    init(rootView: Content) {
        host = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)

        host.view.backgroundColor = .clear
        host.view.insetsLayoutMarginsFromSafeArea = false
        host.additionalSafeAreaInsets = .zero
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.insetsLayoutMarginsFromSafeArea = false
        additionalSafeAreaInsets = .zero

        configureSecureField()
        mountProtectedContentIfReady()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        mountProtectedContentIfReady()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        mountProtectedContentIfReady()
    }

    func update(rootView: Content) {
        host.rootView = rootView

        if secureField.isFirstResponder {
            secureField.resignFirstResponder()
        }

        mountProtectedContentIfReady()
    }

    func dismantle() {
        retryScheduled = false

        if secureField.isFirstResponder {
            secureField.resignFirstResponder()
        }

        if host.parent != nil {
            host.willMove(toParent: nil)
            host.view.removeFromSuperview()
            host.removeFromParent()
        }

        protectedCanvas = nil
        didMountProtectedContent = false
    }

    private func configureSecureField() {
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

        view.addSubview(secureField)
        NSLayoutConstraint.activate([
            secureField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            secureField.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            secureField.topAnchor.constraint(equalTo: view.topAnchor),
            secureField.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Force the first layout pass before asking UITextField for its secure
        // rendering child. There is intentionally no `?? secureField` fallback.
        view.setNeedsLayout()
        view.layoutIfNeeded()
        secureField.setNeedsLayout()
        secureField.layoutIfNeeded()
    }

    private func mountProtectedContentIfReady() {
        guard !didMountProtectedContent else { return }

        secureField.setNeedsLayout()
        secureField.layoutIfNeeded()

        guard let protectedCanvas = secureField.subviews.first else {
            scheduleRetry()
            return
        }

        retryScheduled = false
        self.protectedCanvas = protectedCanvas

        protectedCanvas.isUserInteractionEnabled = true
        protectedCanvas.insetsLayoutMarginsFromSafeArea = false
        protectedCanvas.backgroundColor = .clear

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        protectedCanvas.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: protectedCanvas.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: protectedCanvas.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: protectedCanvas.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: protectedCanvas.bottomAnchor)
        ])

        host.didMove(toParent: self)
        didMountProtectedContent = true

        #if DEBUG
        print(
            "[GRU Privacy] secure chat compositor ready: " +
            NSStringFromClass(type(of: protectedCanvas))
        )
        #endif
    }

    private func scheduleRetry() {
        guard !didMountProtectedContent,
              !retryScheduled,
              retryCount < maxRetryCount else {
            #if DEBUG
            if retryCount >= maxRetryCount && !didMountProtectedContent {
                print("[GRU Privacy] secure canvas unavailable; chat remains redacted")
            }
            #endif
            return
        }

        retryScheduled = true
        retryCount += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.retryScheduled = false
                self.mountProtectedContentIfReady()
            }
        }
    }
}

@MainActor
private struct GRUChatSecureCaptureContainer<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> GRUProtectedChatController<Content> {
        GRUProtectedChatController(rootView: content)
    }

    func updateUIViewController(
        _ uiViewController: GRUProtectedChatController<Content>,
        context: Context
    ) {
        uiViewController.update(rootView: content)
    }

    static func dismantleUIViewController(
        _ uiViewController: GRUProtectedChatController<Content>,
        coordinator: ()
    ) {
        uiViewController.dismantle()
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
            // The approved GRU artwork is intentionally outside the protected
            // compositor. During a still capture, iOS omits the secure chat
            // surface and this is the remaining visible layer.
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
