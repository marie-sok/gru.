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

/// Resolves the Objective-C layer shield at runtime. Keeping this bridge scoped
/// to the chat compositor means RootView, Face ID and login focus never touch
/// the secure-text rendering mechanism.
@MainActor
private final class GRUScreenshotShield {
    private let runtimeObject: NSObject
    private let selector = NSSelectorFromString("protectLayer:")

    init?() {
        guard let runtimeType = NSClassFromString("GRULayerScreenshotShield") as? NSObject.Type else {
            return nil
        }
        runtimeObject = runtimeType.init()
    }

    func protect(_ layer: CALayer) -> Bool {
        guard runtimeObject.responds(to: selector),
              let unmanagedResult = runtimeObject.perform(selector, with: layer) else {
            return false
        }

        let value = unmanagedResult.takeUnretainedValue()
        return (value as? NSNumber)?.boolValue == true
    }
}

/// Owns one regular UIView whose CALayer is explicitly marked as protected by
/// the native shield. Chat pixels remain hidden until that operation succeeds.
/// There is intentionally no unprotected fallback.
@MainActor
private final class GRUProtectedChatController<Content: View>: UIViewController {
    private let protectedContainer = UIView(frame: .zero)
    private let host: UIHostingController<Content>
    private let screenshotShield = GRUScreenshotShield()

    private var didInstallHierarchy = false
    private var isLayerProtected = false
    private var retryScheduled = false
    private var retryCount = 0
    private let maxRetryCount = 120
    private var isDismantled = false
    private var didLogUnavailableShield = false

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

        installProtectedHierarchyIfNeeded()
        applyProtectionIfReady()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyProtectionIfReady()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyProtectionIfReady()
    }

    func update(rootView: Content) {
        guard !isDismantled else { return }
        host.rootView = rootView
        installProtectedHierarchyIfNeeded()
        applyProtectionIfReady()
    }

    func dismantle() {
        isDismantled = true
        retryScheduled = false
        protectedContainer.isHidden = true

        if host.parent != nil {
            host.willMove(toParent: nil)
            host.view.removeFromSuperview()
            host.removeFromParent()
        }

        protectedContainer.removeFromSuperview()
        didInstallHierarchy = false
        isLayerProtected = false
    }

    private func installProtectedHierarchyIfNeeded() {
        guard !didInstallHierarchy,
              !isDismantled else {
            return
        }

        // Fail closed: the GRU privacy artwork underneath remains the only
        // visible surface until the exact container layer is protected.
        protectedContainer.isHidden = true
        protectedContainer.backgroundColor = .clear
        protectedContainer.insetsLayoutMarginsFromSafeArea = false
        protectedContainer.translatesAutoresizingMaskIntoConstraints = false
        protectedContainer.isUserInteractionEnabled = true

        view.addSubview(protectedContainer)
        NSLayoutConstraint.activate([
            protectedContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            protectedContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            protectedContainer.topAnchor.constraint(equalTo: view.topAnchor),
            protectedContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        protectedContainer.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: protectedContainer.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: protectedContainer.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: protectedContainer.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: protectedContainer.bottomAnchor)
        ])

        host.didMove(toParent: self)
        didInstallHierarchy = true

        view.setNeedsLayout()
        view.layoutIfNeeded()
        protectedContainer.setNeedsLayout()
        protectedContainer.layoutIfNeeded()
    }

    private func applyProtectionIfReady() {
        guard !isDismantled,
              didInstallHierarchy,
              !isLayerProtected else {
            return
        }

        view.layoutIfNeeded()
        protectedContainer.layoutIfNeeded()

        guard protectedContainer.bounds.width > 0,
              protectedContainer.bounds.height > 0,
              let screenshotShield,
              screenshotShield.protect(protectedContainer.layer) else {
            scheduleRetry()
            return
        }

        retryScheduled = false
        isLayerProtected = true
        protectedContainer.isHidden = false

        #if DEBUG
        print("[GRU Privacy] chat capture layer protected")
        #endif
    }

    private func scheduleRetry() {
        guard !isDismantled,
              !isLayerProtected,
              !retryScheduled else {
            return
        }

        guard retryCount < maxRetryCount else {
            #if DEBUG
            if !didLogUnavailableShield {
                didLogUnavailableShield = true
                print("[GRU Privacy] secure canvas unavailable; chat remains redacted")
            }
            #endif
            return
        }

        retryScheduled = true
        retryCount += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            Task { @MainActor in
                guard let self,
                      !self.isDismantled else {
                    return
                }

                self.retryScheduled = false
                self.applyProtectionIfReady()
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
            // chat layer. During a still capture, protected conversation pixels
            // are omitted and this scene remains visible underneath.
            GRUPrivacyCaptureScene(
                showButton: screenshotLatch.isLatched,
                onDismiss: screenshotLatch.isLatched ? {
                    screenshotLatch.unlock()
                } : nil
            )

            if !screenshotLatch.isLatched {
                GRUChatSecureCaptureContainer {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .privacySensitive()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
/// It must not use the secure layer compositor because doing so previously
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
