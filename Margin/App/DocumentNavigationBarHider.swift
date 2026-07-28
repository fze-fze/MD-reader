import SwiftUI
import UIKit

/// Keeps DocumentGroup's own navigation bar hidden while a document is open.
///
/// `.toolbarVisibility(.hidden, for: .navigationBar)` covers the normal
/// browse-then-open path, but when another app hands us a file (Files,
/// "Open in…", a share sheet) the document is pushed before SwiftUI applies
/// that preference, so the system bar — back button plus the document title
/// menu — stays on screen above `PagesDocumentNavigationBar`. Bar visibility
/// belongs to the navigation controller rather than to the pushed screen, so
/// the stray bar then survives opening further documents and only goes away
/// when the app is relaunched.
///
/// This enforces the hidden state from UIKit: on appearance, on every layout
/// pass (a bar that comes back changes the safe area, which triggers one), and
/// on each SwiftUI update. Whatever we hid is put back when the document goes
/// away, so the document browser keeps the chrome it had.
struct DocumentNavigationBarHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.hideNavigationBars()
    }

    final class Controller: UIViewController {
        private var hiddenBars: [WeakNavigationController] = []

        override func loadView() {
            let view = LayoutObservingView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
            view.owner = self
            self.view = view
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            hideNavigationBars()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hideNavigationBars()
        }

        override func viewDidDisappear(_ animated: Bool) {
            restoreNavigationBars()
            super.viewDidDisappear(animated)
        }

        /// Hides the bar of every navigation controller containing this
        /// controller, remembering the ones that were actually visible.
        func hideNavigationBars() {
            var controller: UIViewController? = self
            while let current = controller {
                if let navigation = current as? UINavigationController,
                   !navigation.isNavigationBarHidden {
                    if !hiddenBars.contains(where: { $0.value === navigation }) {
                        hiddenBars.append(WeakNavigationController(value: navigation))
                    }
                    navigation.setNavigationBarHidden(true, animated: false)
                }
                controller = current.parent
            }
        }

        /// Restores only the bars this controller hid, so a screen that shows
        /// its navigation bar on purpose is left untouched.
        func restoreNavigationBars() {
            for entry in hiddenBars {
                entry.value?.setNavigationBarHidden(false, animated: false)
            }
            hiddenBars.removeAll()
        }
    }

    private struct WeakNavigationController {
        weak var value: UINavigationController?
    }

    private final class LayoutObservingView: UIView {
        weak var owner: Controller?

        override func layoutSubviews() {
            super.layoutSubviews()
            owner?.hideNavigationBars()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                owner?.hideNavigationBars()
            }
        }
    }
}
