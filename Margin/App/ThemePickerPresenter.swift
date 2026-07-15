import SwiftUI
import UIKit

@MainActor
enum ThemePickerPresenter {
    static func present() {
        guard let presenter = AppPresentationAnchor.topViewController else { return }

        let controller = UIHostingController(
            rootView: ThemeSelectionSheet { [weak presenter] in
                presenter?.dismiss(animated: true)
            }
        )
        controller.modalPresentationStyle = .pageSheet
        controller.sheetPresentationController?.detents = [.medium(), .large()]
        controller.sheetPresentationController?.prefersGrabberVisible = true
        presenter.present(controller, animated: true)
    }
}
