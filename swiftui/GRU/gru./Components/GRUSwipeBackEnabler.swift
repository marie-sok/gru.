import SwiftUI
import UIKit

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
