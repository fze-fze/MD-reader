import Foundation

nonisolated final class RecordingFilePresenter: NSObject, NSFilePresenter, @unchecked Sendable {
    private let lock = NSLock()
    private let moveSemaphore = DispatchSemaphore(value: 0)
    private var currentURL: URL

    let presentedItemOperationQueue = OperationQueue()

    var presentedItemURL: URL? {
        lock.withLock { currentURL }
    }

    init(url: URL) {
        currentURL = url
        super.init()
    }

    func presentedItemDidMove(to newURL: URL) {
        lock.withLock {
            currentURL = newURL
        }
        moveSemaphore.signal()
    }

    func waitForMove(timeout: TimeInterval) -> Bool {
        moveSemaphore.wait(timeout: .now() + timeout) == .success
    }
}
