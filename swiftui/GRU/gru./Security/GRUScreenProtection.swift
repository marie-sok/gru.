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

/// Hosts the complete ChatView. Unlike a single root-layer marker, SwiftUI may
/// create additional compositing/media layers after the host has appeared. Every
/// current layer in the chat subtree is therefore marked with the same Telegram
/// secure-rendering helper, and new layers are picked up on later layout/update
/// passes. If any protection pass cannot be established, the chat fails closed.
@MainActor
private final class GRUTelegramProtectedChatHostController<Content: View>: UIViewController {
    private let host: UIHostingController<Content>
    private var protectedLayerIDs: Set<ObjectIdentifier> = []
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

        // Fail closed: privacy artwork remains visible until the complete
        // current chat layer tree has been marked protected.
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
        applyProtectionToCurrentTree()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        retryCount = 0
        applyProtectionToCurrentTree()
    }

    func update(rootView: Content) {
        host.rootView = rootView
        applyProtectionToCurrentTree()

        // SwiftUI can materialize additional rendering layers after update.
        DispatchQueue.main.async { [weak self] in
            self?.applyProtectionToCurrentTree()
        }
    }

    private func applyProtectionToCurrentTree() {
        guard isViewLoaded,
              view.window != nil,
              view.bounds.width > 1,
              view.bounds.height > 1,
              host.view.bounds.width > 1,
              host.view.bounds.height > 1 else {
            host.view.isHidden = true
            scheduleRetry()
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let layers = uniqueLayerTree()
        var passSucceeded = true

        for layer in layers {
            let identifier = ObjectIdentifier(layer)
            guard !protectedLayerIDs.contains(identifier) else { continue }

            if GRUTelegramLayerScreenshotGuard.setProtected(layer, enabled: true) {
                protectedLayerIDs.insert(identifier)
            } else {
                passSucceeded = false
                break
            }
        }

        CATransaction.commit()

        let rootsProtected = protectedLayerIDs.contains(ObjectIdentifier(view.layer)) &&
            protectedLayerIDs.contains(ObjectIdentifier(host.view.layer))

        guard passSucceeded && rootsProtected else {
            host.view.isHidden = true
            scheduleRetry()
            return
        }

        host.view.isHidden = false
        retryWorkItem?.cancel()
        retryWorkItem = nil

        #if DEBUG
        print("[GRU Privacy] secure chat layer tree protected: \(protectedLayerIDs.count) layers")
        #endif
    }

    private func uniqueLayerTree() -> [CALayer] {
        var result: [CALayer] = []
        var seen: Set<ObjectIdentifier> = []
        var queue: [CALayer] = [view.layer, host.view.layer]

        while !queue.isEmpty {
            let layer = queue.removeFirst()
            let identifier = ObjectIdentifier(layer)
            guard seen.insert(identifier).inserted else { continue }

            result.append(layer)
            if let sublayers = layer.sublayers {
                queue.append(contentsOf: sublayers)
            }
        }

        return result
    }

    private func scheduleRetry() {
        guard retryWorkItem == nil, retryCount < 120 else { return }

        retryCount += 1
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.retryWorkItem = nil
            self.applyProtectionToCurrentTree()
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
