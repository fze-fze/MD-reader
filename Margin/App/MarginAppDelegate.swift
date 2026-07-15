import UIKit

final class MarginAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem else {
            return true
        }
        return !HomeScreenQuickAction.handles(shortcutItem)
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(HomeScreenQuickAction.handles(shortcutItem))
    }
}
