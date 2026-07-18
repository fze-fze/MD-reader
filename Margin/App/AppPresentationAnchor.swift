import UIKit

@MainActor
enum AppPresentationAnchor {
    static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }

    static var topViewController: UIViewController? {
        topViewController(from: rootViewController)
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
