import Foundation

@MainActor
@Observable
final class DocumentSessionStore {
    static let shared = DocumentSessionStore()

    private var sessionsByURL: [URL: DocumentSession] = [:]

    func session(for sourceURL: URL, bootstrapText: String) -> DocumentSession {
        let key = Self.canonicalURL(sourceURL)
        if let session = sessionsByURL[key] {
            return session
        }

        let session = DocumentSession(
            text: bootstrapText,
            fileURL: sourceURL,
            store: self
        )
        sessionsByURL[key] = session
        return session
    }

    func registerMove(
        of session: DocumentSession,
        from sourceURL: URL,
        to destinationURL: URL
    ) {
        sessionsByURL[Self.canonicalURL(sourceURL)] = session
        sessionsByURL[Self.canonicalURL(destinationURL)] = session
    }

    private static func canonicalURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
