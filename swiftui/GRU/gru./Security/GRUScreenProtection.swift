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

@MainActor
private final class GRUProtectedChatHostController<Content: View>: UIViewController {
    private let protectedContainer = UIView(frame: .zero)
    private let host: UIHostingController<Content>

    private var protectionApplied = false
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

        protectedContainer.backgroundColor = .clear
        protectedContainer.translatesAutoresizingMaskIntoConstraints = false
        protectedContainer.isHidden = true
        protectedContainer.clipsToBounds = false

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
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        retryCount = 0
        applyProtectionIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyProtectionIfNeeded()
    }

    func update(rootView: Content) {
        host.rootView = rootView
        applyProtectionIfNeeded()
    }

    private func applyProtectionIfNeeded() {
        guard !protectionApplied else {
            protectedContainer.isHidden = false
            return
        }

        guard isViewLoaded,
              view.window != nil,
              protectedContainer.bounds.width > 1,
              protectedContainer.bounds.height > 1 else {
            protectedContainer.isHidden = true
            scheduleRetry()
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let didProtect = GRUSecureLayerBridge.setProtected(
            protectedContainer.layer,
            enabled: true
        )
        CATransaction.commit()

        guard didProtect else {
            protectedContainer.isHidden = true
            scheduleRetry()
            return
        }

        protectionApplied = true
        protectedContainer.isHidden = false
        retryWorkItem?.cancel()
        retryWorkItem = nil

        print("[GRU Privacy] Objective-C secure chat layer enabled")
    }

    private func scheduleRetry() {
        guard retryWorkItem == nil, retryCount < 120 else { return }

        retryCount += 1
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.retryWorkItem = nil
            self.applyProtectionIfNeeded()
        }

        retryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    func disableProtection() {
        guard protectionApplied else { return }
        _ = GRUSecureLayerBridge.setProtected(protectedContainer.layer, enabled: false)
        protectionApplied = false
    }
}

private struct GRUChatSecureCaptureContainer<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> GRUProtectedChatHostController<Content> {
        GRUProtectedChatHostController(rootView: content)
    }

    func updateUIViewController(
        _ uiViewController: GRUProtectedChatHostController<Content>,
        context: Context
    ) {
        uiViewController.update(rootView: content)
    }

    static func dismantleUIViewController(
        _ uiViewController: GRUProtectedChatHostController<Content>,
        coordinator: ()
    ) {
        uiViewController.disableProtection()
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
