import UIKit

@MainActor
enum AppPresentationAnchor {
    static var topViewController: UIViewController? {
        let rootController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController

        return topViewController(from: rootController)
    }

    private static func topViewController(from controller: UIViewController?) -> UIViewController? {
        if let presented = controller?.presentedViewController {
            return topViewController(from: presented)
        }

        if let navigationController = controller as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        }

        if let tabBarController = controller as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController)
        }

        return controller
    }
}
