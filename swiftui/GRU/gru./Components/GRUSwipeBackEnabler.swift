import SwiftUI
import UIKit

/// Restores the standard UINavigationController interactive edge-pop gesture
/// when SwiftUI's custom chat header hides the stock back button.
///
/// The view itself is invisible and never intercepts chat touches. This keeps
/// vertical message scrolling and the existing left-swipe-to-reply gesture
/// independent from the system right-edge-back interaction.
struct GRUSwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = GRUSwipeBackProbeController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {
        DispatchQueue.main.async {
            Self.enableInteractivePop(from: uiViewController)
        }
    }

    static func dismantleUIViewController(
        _ uiViewController: UIViewController,
        coordinator: ()
    ) {
        // Do not disable the recognizer on teardown. UINavigationController
        // owns its lifecycle and will configure it for the next destination.
    }

    fileprivate static func enableInteractivePop(
        from controller: UIViewController
    ) {
        guard
            let navigationController = controller.navigationController,
            navigationController.viewControllers.count > 1,
            let recognizer = navigationController.interactivePopGestureRecognizer
        else {
            return
        }

        recognizer.isEnabled = true

        // Hiding SwiftUI's stock Back button commonly installs a delegate that
        // suppresses interactive pop. Removing it returns UIKit's normal edge
        // gesture behavior for this NavigationStack.
        recognizer.delegate = nil
    }
}

private final class GRUSwipeBackProbeController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            GRUSwipeBackEnabler.enableInteractivePop(from: self)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        GRUSwipeBackEnabler.enableInteractivePop(from: self)
    }
}
