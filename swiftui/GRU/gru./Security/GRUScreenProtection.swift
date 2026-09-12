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

/// Mirrors Telegram-iOS' UIKitRuntimeUtils implementation as closely as possible:
/// one plain UITextField, its TextLayoutCanvasView, temporary layer substitution,
/// then secureTextEntry false -> true.
@MainActor
private enum GRUTelegramLayerScreenshotGuard {
    private static let textField = UITextField()

    private static let secureView: UIView? = {
        for subview in textField.subviews {
            if NSStringFromClass(type(of: subview)).contains("TextLayoutCanvasView") {
                return subview
            }
        }

        // Compatibility only: current Telegram uses the direct-child path above.
        var queue = textField.subviews
        while !queue.isEmpty {
            let candidate = queue.removeFirst()
            let name = NSStringFromClass(type(of: candidate))
            if name.contains("TextLayoutCanvasView") || name.contains("LayoutCanvasView") {
                return candidate
            }
            queue.append(contentsOf: candidate.subviews)
        }

        return nil
    }()

    @discardableResult
    static func setProtected(_ layer: CALayer, enabled: Bool) -> Bool {
        guard let secureView else { return false }

        let previousLayer = secureView.layer
        secureView.setValue(layer, forKey: "layer")

        if enabled {
            textField.isSecureTextEntry = false
            textField.isSecureTextEntry = true
        } else {
            textField.isSecureTextEntry = true
            textField.isSecureTextEntry = false
        }

        secureView.setValue(previousLayer, forKey: "layer")
        return true
    }
}

/// Hosts the complete ChatView and protects the representable controller's root
/// layer. The approved cyberpunk cat is rendered as a sibling underneath it.
/// No secure UITextField enters the responder or view hierarchy.
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

        // Fail closed: until the exact Telegram-style marker is applied, the
        // real chat remains hidden and the cyberpunk privacy scene underneath is visible.
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
              view.bounds.width > 1,
              view.bounds.height > 1,
              host.view.bounds.width > 1,
              host.view.bounds.height > 1 else {
            scheduleRetry()
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Telegram protects a container layer. Protect our outer chat container
        // and the SwiftUI host root as a belt-and-suspenders measure.
        let outerProtected = GRUTelegramLayerScreenshotGuard.setProtected(
            view.layer,
            enabled: true
        )
        let hostProtected = GRUTelegramLayerScreenshotGuard.setProtected(
            host.view.layer,
            enabled: true
        )

        CATransaction.commit()

        guard outerProtected && hostProtected else {
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
        guard retryWorkItem == nil, retryCount < 100 else { return }

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

/// Applied only by ChatView. The real chat is a protected sibling above the
/// approved privacy artwork; if protection cannot be established, fail closed.
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

/// Root protection remains public-API-only. Still-screenshot layer marking stays
/// inside authenticated ChatView so LocalAuthentication and login are untouched.
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
