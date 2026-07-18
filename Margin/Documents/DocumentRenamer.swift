import Foundation
import UIKit

@MainActor
enum DocumentRenamer {
    static func isValidName(_ proposedName: String) -> Bool {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name != "." && name != ".." && !name.contains("/")
    }

    static func rename(fileAt sourceURL: URL, to proposedName: String) async throws -> URL {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidName(trimmedName) else {
            throw renameError(L10n.string("document.error.invalid_name"))
        }

        let baseName = removingExtension(sourceURL.pathExtension, from: trimmedName)
        guard baseName != sourceURL.deletingPathExtension().lastPathComponent else {
            return sourceURL
        }
        guard let documentBrowser = activeDocumentBrowser else {
            throw renameError(L10n.string("document.error.rename_unavailable"))
        }

        return try await withCheckedThrowingContinuation { continuation in
            // UIDocumentBrowserViewController performs the rename through the
            // document provider, so the destination does not require a new
            // sandbox extension owned by this process.
            documentBrowser.renameDocument(
                at: sourceURL,
                proposedName: baseName
            ) { finalURL, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let finalURL {
                    continuation.resume(returning: finalURL)
                } else {
                    continuation.resume(
                        throwing: renameError(
                            L10n.string("document.error.rename_unavailable")
                        )
                    )
                }
            }
        }
    }

    private static var activeDocumentBrowser: UIDocumentBrowserViewController? {
        documentBrowser(in: AppPresentationAnchor.rootViewController)
    }

    static func documentBrowser(
        in controller: UIViewController?
    ) -> UIDocumentBrowserViewController? {
        guard let controller else { return nil }

        if let browser = controller as? UIDocumentBrowserViewController {
            return browser
        }
        if let documentController = controller as? UIDocumentViewController {
            return documentController.launchOptions.browserViewController
        }
        if let browser = documentBrowser(in: controller.presentedViewController) {
            return browser
        }
        for child in controller.children {
            if let browser = documentBrowser(in: child) {
                return browser
            }
        }
        return nil
    }

    private static func removingExtension(
        _ pathExtension: String,
        from proposedName: String
    ) -> String {
        guard !pathExtension.isEmpty,
              proposedName.lowercased().hasSuffix(".\(pathExtension.lowercased())") else {
            return proposedName
        }
        return String(proposedName.dropLast(pathExtension.count + 1))
    }

    private static func renameError(_ message: String) -> NSError {
        NSError(
            domain: "com.fze.margin.rename",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
