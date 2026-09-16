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

/// A real secure UITextField remains mounted for the entire lifetime of the
/// chat surface. GRU does not temporarily swap unrelated CALayers anymore.
/// Instead, the rendered chat hierarchy is physically mounted inside UIKit's
/// exact TextLayoutCanvasView while secureTextEntry remains enabled.
private final class GRUSecureCanvasTextField: UITextField {
    override func textRect(forBounds bounds: CGRect) -> CGRect { bounds }
    override func editingRect(forBounds bounds: CGRect) -> CGRect { bounds }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect { bounds }
}

@MainActor
private final class GRUSecureChatSurfaceView: UIView {
    private let secureField = GRUSecureCanvasTextField(frame: .zero)
    private weak var mountedContentView: UIView?
    private weak var activeSecureCanvas: UIView?

    private(set) var secureCanvasClassName: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSecureField()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        secureField.frame = bounds
        secureField.layoutIfNeeded()

        guard let contentView = mountedContentView,
              let canvas = resolveExactSecureCanvas() else {
            return
        }

        if activeSecureCanvas !== canvas || contentView.superview !== canvas {
            attach(contentView, to: canvas)
        }

        contentView.frame = canvas.bounds
    }

    func mount(_ contentView: UIView) -> Bool {
        mountedContentView = contentView

        setNeedsLayout()
        layoutIfNeeded()
        secureField.setNeedsLayout()
        secureField.layoutIfNeeded()

        guard let canvas = resolveExactSecureCanvas() else {
            return false
        }

        if activeSecureCanvas !== canvas || contentView.superview !== canvas {
            attach(contentView, to: canvas)
        }

        contentView.frame = canvas.bounds
        return contentView.superview === canvas && canvas.isDescendant(of: secureField)
    }

    func unmount() {
        mountedContentView?.removeFromSuperview()
        mountedContentView = nil
        activeSecureCanvas = nil
        secureCanvasClassName = nil
    }

    private func configureSecureField() {
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = true

        secureField.frame = bounds
        secureField.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        secureField.backgroundColor = .clear
        secureField.borderStyle = .none
        secureField.textColor = .clear
        secureField.tintColor = .clear
        secureField.text = " "
        secureField.isSecureTextEntry = true
        secureField.isUserInteractionEnabled = true
        secureField.clipsToBounds = true

        addSubview(secureField)
        secureField.setNeedsLayout()
        secureField.layoutIfNeeded()
    }

    private func resolveExactSecureCanvas() -> UIView? {
        if let activeSecureCanvas,
           activeSecureCanvas.isDescendant(of: secureField),
           isExactSecureCanvas(activeSecureCanvas) {
            return activeSecureCanvas
        }

        var queue = secureField.subviews
        while !queue.isEmpty {
            let candidate = queue.removeFirst()

            if isExactSecureCanvas(candidate) {
                activeSecureCanvas = candidate
                secureCanvasClassName = NSStringFromClass(type(of: candidate))
                return candidate
            }

            queue.append(contentsOf: candidate.subviews)
        }

        activeSecureCanvas = nil
        secureCanvasClassName = nil
        return nil
    }

    private func isExactSecureCanvas(_ view: UIView) -> Bool {
        NSStringFromClass(type(of: view)).contains("TextLayoutCanvasView")
    }

    private func attach(_ contentView: UIView, to canvas: UIView) {
        contentView.removeFromSuperview()
        contentView.translatesAutoresizingMaskIntoConstraints = true
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.frame = canvas.bounds

        canvas.isUserInteractionEnabled = true
        canvas.clipsToBounds = true
        canvas.addSubview(contentView)

        activeSecureCanvas = canvas
        secureCanvasClassName = NSStringFromClass(type(of: canvas))
    }

    #if DEBUG
    func secureHierarchyDiagnostic() -> [String] {
        var names: [String] = []
        var queue = secureField.subviews

        while !queue.isEmpty {
            let candidate = queue.removeFirst()
            names.append(NSStringFromClass(type(of: candidate)))
            queue.append(contentsOf: candidate.subviews)
        }

        return names
    }
    #endif
}

/// Hosts all SwiftUI chat pixels inside one persistent secure UITextField
/// canvas. The privacy artwork underneath stays visible until the exact secure
/// canvas exists and the hosting view is confirmed as its descendant.
@MainActor
private final class GRUProtectedChatController<Content: View>: UIViewController {
    private let secureSurface = GRUSecureChatSurfaceView(frame: .zero)
    private let host: UIHostingController<Content>

    private var didInstallHierarchy = false
    private var isSecureCanvasMounted = false
    private var retryScheduled = false
    private var retryCount = 0
    private let maxRetryCount = 120
    private var isDismantled = false
    private var didLogUnavailableCanvas = false

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

        installHierarchyIfNeeded()
        mountSecureCanvasIfReady()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        mountSecureCanvasIfReady()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        mountSecureCanvasIfReady()
    }

    func update(rootView: Content) {
        guard !isDismantled else { return }
        host.rootView = rootView
        installHierarchyIfNeeded()
        mountSecureCanvasIfReady()
    }

    func dismantle() {
        isDismantled = true
        retryScheduled = false
        secureSurface.isHidden = true
        secureSurface.unmount()

        if host.parent != nil {
            host.willMove(toParent: nil)
            host.view.removeFromSuperview()
            host.removeFromParent()
        }

        secureSurface.removeFromSuperview()
        didInstallHierarchy = false
        isSecureCanvasMounted = false
    }

    private func installHierarchyIfNeeded() {
        guard !didInstallHierarchy,
              !isDismantled else {
            return
        }

        // Fail closed: chat pixels are never shown outside the exact secure
        // text canvas. Until it exists, only GRU privacy artwork is visible.
        secureSurface.isHidden = true
        secureSurface.backgroundColor = .clear
        secureSurface.insetsLayoutMarginsFromSafeArea = false
        secureSurface.translatesAutoresizingMaskIntoConstraints = false
        secureSurface.isUserInteractionEnabled = true

        view.addSubview(secureSurface)
        NSLayoutConstraint.activate([
            secureSurface.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            secureSurface.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            secureSurface.topAnchor.constraint(equalTo: view.topAnchor),
            secureSurface.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        addChild(host)
        host.didMove(toParent: self)
        didInstallHierarchy = true

        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func mountSecureCanvasIfReady() {
        guard !isDismantled,
              didInstallHierarchy else {
            return
        }

        view.layoutIfNeeded()
        secureSurface.layoutIfNeeded()

        guard secureSurface.bounds.width > 0,
              secureSurface.bounds.height > 0,
              secureSurface.mount(host.view) else {
            isSecureCanvasMounted = false
            secureSurface.isHidden = true
            scheduleRetry()
            return
        }

        retryScheduled = false

        if !isSecureCanvasMounted {
            isSecureCanvasMounted = true
            secureSurface.isHidden = false

            #if DEBUG
            print(
                "[GRU Privacy] secure chat canvas mounted:",
                secureSurface.secureCanvasClassName ?? "unknown"
            )
            #endif
        } else if secureSurface.isHidden {
            secureSurface.isHidden = false
        }
    }

    private func scheduleRetry() {
        guard !isDismantled,
              !isSecureCanvasMounted,
              !retryScheduled else {
            return
        }

        guard retryCount < maxRetryCount else {
            #if DEBUG
            if !didLogUnavailableCanvas {
                didLogUnavailableCanvas = true
                print("[GRU Privacy] exact secure text canvas unavailable; chat remains redacted")
                print("[GRU Privacy] UITextField hierarchy:", secureSurface.secureHierarchyDiagnostic())
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
                self.mountSecureCanvasIfReady()
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
            // The approved GRU artwork is intentionally outside the secure chat
            // canvas. iOS may still create a screenshot file, but protected chat
            // pixels should be omitted from that file while this scene remains.
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
/// It must not use the secure chat compositor because doing so previously
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
