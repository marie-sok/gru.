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
              UIApplication.shared.applicationState == .active
        else {
            return
        }

        isPrivacyShieldActive = false
    }
}

// MARK: - Chat-only still screenshot protection

/// This field exists only inside an authenticated chat surface. It never wraps
/// RootView or the authentication flow and therefore cannot participate in the
/// Face ID / device-passcode lifecycle that previously regressed on iPhone.
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

/// Best-effort secure compositor scoped to ChatView only.
///
/// The visible chat is hosted inside the secure text compositor. A normal
/// SwiftUI privacy scene sits behind it. On iOS builds where secure text layers
/// are omitted from still capture, the screenshot therefore reveals the GRU
/// privacy scene instead of the conversation.
private struct GRUChatSecureCaptureContainer<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(rootView: content)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let container = UIViewController()
        container.view.backgroundColor = .clear
        container.view.insetsLayoutMarginsFromSafeArea = false
        container.additionalSafeAreaInsets = .zero

        let secureField = GRUChatNonResponderSecureField(frame: .zero)
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

        // This host can never summon its own keyboard. Real ChatInputBar fields
        // remain independent responders inside the hosted SwiftUI hierarchy.
        secureField.inputView = UIView(frame: .zero)
        secureField.inputAccessoryView = UIView(frame: .zero)

        container.view.addSubview(secureField)
        NSLayoutConstraint.activate([
            secureField.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
            secureField.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
            secureField.topAnchor.constraint(equalTo: container.view.topAnchor),
            secureField.bottomAnchor.constraint(equalTo: container.view.bottomAnchor)
        ])

        guard let protectedCanvas = secureField.subviews.first else {
            // Fail open for normal interaction if Apple changes the private
            // secure-text view hierarchy on a future iOS release.
            let host = context.coordinator.host
            container.addChild(host)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            host.view.backgroundColor = .clear
            container.view.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: container.view.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: container.view.bottomAnchor)
            ])
            host.didMove(toParent: container)
            context.coordinator.secureField = secureField
            return container
        }

        protectedCanvas.isUserInteractionEnabled = true
        protectedCanvas.insetsLayoutMarginsFromSafeArea = false
        protectedCanvas.backgroundColor = .clear

        let host = context.coordinator.host
        host.view.backgroundColor = .clear
        host.view.insetsLayoutMarginsFromSafeArea = false
        host.additionalSafeAreaInsets = .zero

        container.addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        protectedCanvas.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: protectedCanvas.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: protectedCanvas.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: protectedCanvas.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: protectedCanvas.bottomAnchor)
        ])
        host.didMove(toParent: container)

        context.coordinator.secureField = secureField
        context.coordinator.protectedCanvas = protectedCanvas
        return container
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {
        context.coordinator.host.rootView = content
        if context.coordinator.secureField?.isFirstResponder == true {
            context.coordinator.secureField?.resignFirstResponder()
        }
    }

    static func dismantleUIViewController(
        _ uiViewController: UIViewController,
        coordinator: Coordinator
    ) {
        if coordinator.secureField?.isFirstResponder == true {
            coordinator.secureField?.resignFirstResponder()
        }
        coordinator.host.willMove(toParent: nil)
        coordinator.host.view.removeFromSuperview()
        coordinator.host.removeFromParent()
    }

    final class Coordinator {
        let host: UIHostingController<Content>
        weak var secureField: GRUChatNonResponderSecureField?
        weak var protectedCanvas: UIView?

        init(rootView: Content) {
            host = UIHostingController(rootView: rootView)
            host.view.backgroundColor = .clear
        }
    }
}

/// Apply this only to the visual surface of ChatView. The fallback is always
/// behind the secure chat, so it is ready before the user presses the hardware
/// screenshot buttons rather than reacting after capture.
struct GRUChatCaptureProtection<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            GRUPrivacyCaptureScene(showButton: true, onDismiss: nil)

            GRUChatSecureCaptureContainer {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - GRU privacy scene

private struct GRUPrivacyEar: Shape {
    var flip = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if flip {
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

private struct GRUNeonPrivacyCat: View {
    private var accent: Color { GRUColors.accent }
    private var second: Color { GRUColors.accentSecondary }

    var body: some View {
        ZStack {
            // Hoodie / body
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(Color.black.opacity(0.42))
                .overlay {
                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                        .stroke(accent.opacity(0.80), lineWidth: 2)
                }
                .frame(width: 164, height: 150)
                .offset(y: 64)

            // Shrugging arms
            Capsule()
                .fill(Color.black.opacity(0.46))
                .overlay { Capsule().stroke(accent.opacity(0.72), lineWidth: 2) }
                .frame(width: 92, height: 34)
                .rotationEffect(.degrees(-30))
                .offset(x: -82, y: 62)

            Capsule()
                .fill(Color.black.opacity(0.46))
                .overlay { Capsule().stroke(accent.opacity(0.72), lineWidth: 2) }
                .frame(width: 92, height: 34)
                .rotationEffect(.degrees(30))
                .offset(x: 82, y: 62)

            // Paws
            Circle()
                .fill(Color.black.opacity(0.72))
                .overlay { Circle().stroke(second.opacity(0.90), lineWidth: 2) }
                .frame(width: 43, height: 43)
                .offset(x: -121, y: 35)
                .overlay(alignment: .center) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(second)
                        .offset(x: -121, y: 35)
                }

            Circle()
                .fill(Color.black.opacity(0.72))
                .overlay { Circle().stroke(second.opacity(0.90), lineWidth: 2) }
                .frame(width: 43, height: 43)
                .offset(x: 121, y: 35)
                .overlay(alignment: .center) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(second)
                        .offset(x: 121, y: 35)
                }

            // Ears
            GRUPrivacyEar()
                .fill(Color.black.opacity(0.74))
                .overlay { GRUPrivacyEar().stroke(accent.opacity(0.86), lineWidth: 2) }
                .frame(width: 58, height: 64)
                .rotationEffect(.degrees(-7))
                .offset(x: -58, y: -63)

            GRUPrivacyEar(flip: true)
                .fill(Color.black.opacity(0.74))
                .overlay { GRUPrivacyEar(flip: true).stroke(accent.opacity(0.86), lineWidth: 2) }
                .frame(width: 58, height: 64)
                .rotationEffect(.degrees(7))
                .offset(x: 58, y: -63)

            // Head
            Ellipse()
                .fill(Color.black.opacity(0.70))
                .overlay { Ellipse().stroke(accent.opacity(0.88), lineWidth: 2.2) }
                .frame(width: 170, height: 132)
                .offset(y: -16)

            // Eyes — one wide, one wink
            Circle()
                .fill(accent.opacity(0.92))
                .frame(width: 24, height: 30)
                .overlay {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 10, height: 16)
                }
                .offset(x: -36, y: -22)

            Capsule()
                .fill(accent.opacity(0.92))
                .frame(width: 30, height: 4)
                .rotationEffect(.degrees(-8))
                .offset(x: 37, y: -20)

            // Nose / mouth
            Circle()
                .fill(second)
                .frame(width: 8, height: 7)
                .offset(y: 2)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(second.opacity(0.9))
                    .frame(width: 1.5, height: 9)
                HStack(spacing: 1) {
                    ArcSmile(flip: false)
                    ArcSmile(flip: true)
                }
                .frame(width: 34, height: 14)
            }
            .offset(y: 8)

            // Hoodie label
            Text("ШТОШ")
                .font(.system(size: 19, weight: .black, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(Color.white.opacity(0.82))
                .offset(y: 82)
        }
        .frame(width: 300, height: 280)
        .shadow(color: accent.opacity(0.34), radius: 18)
        .accessibilityHidden(true)
    }
}

private struct ArcSmile: Shape {
    let flip: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: flip ? rect.maxX : rect.minX, y: rect.minY)
        let end = CGPoint(x: rect.midX, y: rect.maxY)
        path.move(to: start)
        path.addQuadCurve(
            to: end,
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

struct GRUPrivacyCaptureScene: View {
    var showButton = false
    var onDismiss: (() -> Void)?

    private var isEnglish: Bool {
        GRUAppLanguage.selected == .english
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    GRUColors.background.opacity(0.98),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            privacyDoodles
                .opacity(0.18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    HStack {
                        Text("gru.")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .tracking(-1.1)

                        Circle()
                            .fill(GRUColors.accent)
                            .frame(width: 7, height: 7)

                        Spacer()

                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(GRUColors.accent)
                    }
                    .padding(.top, 16)

                    Spacer(minLength: 12)

                    ZStack(alignment: .topTrailing) {
                        GRUNeonPrivacyCat()

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Упс…")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(GRUColors.accent)

                            Text("this stays between us")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .rotationEffect(.degrees(-4))
                        .offset(x: 8, y: 12)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 10) {
                        Text(isEnglish ? "Privacy matters" : "Частная жизнь имеет значение")
                            .font(.system(size: 29, weight: .black, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)

                        Text(
                            isEnglish
                                ? "gru. respects the value of privacy. A conversation between two people should stay between them."
                                : "gru. уважает ценность частной жизни. Разговор между двумя людьми должен оставаться между ними."
                        )
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                    }

                    HStack(spacing: 13) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(GRUColors.accent)
                            .frame(width: 42, height: 42)
                            .background(GRUColors.accent.opacity(0.10), in: Circle())

                        Text(
                            isEnglish
                                ? "Screen recording, broadcasting and app previews are hidden to keep private conversations private."
                                : "Запись экрана, трансляция и превью приложения скрываются, чтобы личный разговор оставался личным."
                        )
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(GRUColors.card.opacity(0.80), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(GRUColors.accent.opacity(0.16), lineWidth: 1)
                    }

                    if showButton {
                        if let onDismiss {
                            Button(action: onDismiss) {
                                privacyButtonLabel
                            }
                            .buttonStyle(.plain)
                        } else {
                            privacyButtonLabel
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isEnglish ? "Privacy matters" : "Частная жизнь имеет значение")
    }

    private var privacyButtonLabel: some View {
        Text(isEnglish ? "Got it" : "Понятно")
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(GRUColors.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(GRUColors.accent.opacity(0.76), lineWidth: 1.5)
            }
    }

    private var privacyDoodles: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            Group {
                Image(systemName: "envelope")
                    .offset(x: w * 0.10, y: h * 0.16)
                Image(systemName: "heart")
                    .offset(x: w * 0.76, y: h * 0.21)
                Image(systemName: "pawprint.fill")
                    .offset(x: w * 0.18, y: h * 0.72)
                Image(systemName: "bubble.left")
                    .offset(x: w * 0.74, y: h * 0.64)
                Image(systemName: "envelope.fill")
                    .offset(x: w * 0.62, y: h * 0.84)
                Image(systemName: "pawprint")
                    .offset(x: w * 0.08, y: h * 0.46)
            }
            .font(.system(size: 30, weight: .regular))
            .foregroundStyle(GRUColors.accent)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
