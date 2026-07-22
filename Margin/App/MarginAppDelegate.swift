import UIKit

final class MarginAppDelegate: NSObject, UIApplicationDelegate {
    // The reader trades memory for scrolling smoothness (styled text, math
    // images, math segmentation). Hand it back when the system asks; every
    // entry is derived data that rebuilds on demand.
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        MathRenderer.purgeCache()
        InlineMarkdownStyler.purgeCache()
        InlineMathSegmenter.purgeCache()
    }
}
