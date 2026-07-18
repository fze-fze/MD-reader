import SwiftUI
import UIKit

struct InteractivePopGestureRestorer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.enableGestureIfPossible()
    }

    final class Controller: UIViewController {
        private weak var gestureRecognizer: UIGestureRecognizer?
        private var delegateProxy: DelegateProxy?

        override func loadView() {
            let view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
            self.view = view
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enableGestureIfPossible()
        }

        override func viewDidDisappear(_ animated: Bool) {
            restoreGestureDelegate()
            super.viewDidDisappear(animated)
        }

        func enableGestureIfPossible() {
            guard let navigationController,
                  navigationController.viewControllers.count > 1,
                  let gesture = navigationController.interactivePopGestureRecognizer else {
                return
            }

            if gestureRecognizer !== gesture || gesture.delegate !== delegateProxy {
                restoreGestureDelegate()
                let proxy = DelegateProxy(
                    navigationController: navigationController,
                    originalDelegate: gesture.delegate
                )
                gestureRecognizer = gesture
                delegateProxy = proxy
                gesture.delegate = proxy
            }
            gesture.isEnabled = true
        }

        private func restoreGestureDelegate() {
            guard let gestureRecognizer, let delegateProxy else {
                return
            }
            if gestureRecognizer.delegate === delegateProxy {
                gestureRecognizer.delegate = delegateProxy.originalDelegate
            }
            self.delegateProxy = nil
        }
    }

    final class DelegateProxy: NSObject, UIGestureRecognizerDelegate {
        private weak var navigationController: UINavigationController?
        fileprivate weak var originalDelegate: (any UIGestureRecognizerDelegate)?

        init(
            navigationController: UINavigationController,
            originalDelegate: (any UIGestureRecognizerDelegate)?
        ) {
            self.navigationController = navigationController
            self.originalDelegate = originalDelegate
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let navigationController else { return false }
            return navigationController.viewControllers.count > 1
                && navigationController.transitionCoordinator == nil
        }
    }
}
