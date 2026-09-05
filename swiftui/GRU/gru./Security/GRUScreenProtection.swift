import SwiftUI
import UIKit

@MainActor
final class GRUScreenProtectionModel: ObservableObject {
    @Published private(set) var isCaptureActive = false
    @Published var showScreenshotWarning = false

    private var observers: [NSObjectProtocol] = []

    init() {
        refreshCaptureState()

        observers.append(
            NotificationCenter.default.addObserver(
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
            NotificationCenter.default.addObserver(
                forName: UIApplication.userDidTakeScreenshotNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.showScreenshotWarning = true
                }
            }
        )
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func refreshCaptureState() {
        isCaptureActive = UIScreen.main.isCaptured
    }
}

/// Protects the visible app hierarchy with the same secure compositor path
/// used by secure text entry. This is a best-effort privacy layer for still
/// captures; active recording/mirroring is additionally blocked explicitly.
struct GRUSecureContent<Content: View>: UIViewControllerRepresentable {
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

        let secureField = UITextField(frame: .zero)
        secureField.isSecureTextEntry = true
        secureField.text = " "
        secureField.textColor = .clear
        secureField.tintColor = .clear
        secureField.backgroundColor = .clear
        secureField.translatesAutoresizingMaskIntoConstraints = false
        secureField.accessibilityElementsHidden = true
        container.view.addSubview(secureField)

        NSLayoutConstraint.activate([
            secureField.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
            secureField.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
            secureField.topAnchor.constraint(equalTo: container.view.topAnchor),
            secureField.bottomAnchor.constraint(equalTo: container.view.bottomAnchor)
        ])

        let protectedCanvas = secureField.subviews.first ?? secureField
        protectedCanvas.isUserInteractionEnabled = true

        let host = context.coordinator.host
        container.addChild(host)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        protectedCanvas.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: protectedCanvas.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: protectedCanvas.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: protectedCanvas.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: protectedCanvas.bottomAnchor)
        ])

        host.didMove(toParent: container)
        return container
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.host.rootView = content
    }

    final class Coordinator {
        let host: UIHostingController<Content>

        init(rootView: Content) {
            host = UIHostingController(rootView: rootView)
        }
    }
}

struct GRUScreenProtectionView<Content: View>: View {
    @StateObject private var model = GRUScreenProtectionModel()
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            GRUSecureContent {
                content
            }

            if model.isCaptureActive {
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 14) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(GRUColors.accent)

                        Text("Контент защищён")
                            .font(.title3.bold())
                            .foregroundStyle(.white)

                        Text("Запись экрана и трансляция отключены для защиты переписки в gru.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                }
                .zIndex(1000)
            }
        }
        .alert("Защита gru.", isPresented: $model.showScreenshotWarning) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Снимки экрана ограничены. Защищённый контент gru. скрывается от захвата, а запись и трансляция блокируются.")
        }
    }
}
