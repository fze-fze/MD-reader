import Foundation
import UIKit

@MainActor
enum DocumentSharePresenter {
    static func present(markdown: String, suggestedName: String) async throws {
        let sharedFile = try makeTemporaryFile(
            markdown: markdown,
            suggestedName: suggestedName
        )
        try await present(fileAt: sharedFile)
    }

    static func present(fileAt sharedFile: URL) async throws {
        // The title menu needs to finish dismissing before UIKit can present
        // the activity controller from the document window.
        try await Task.sleep(for: .milliseconds(250))

        guard let presenter = AppPresentationAnchor.topViewController else {
            try? FileManager.default.removeItem(at: sharedFile.deletingLastPathComponent())
            throw DocumentShareError.noActiveWindow
        }

        let controller = UIActivityViewController(
            activityItems: [sharedFile],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: sharedFile.deletingLastPathComponent())
        }

        if let popover = controller.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 1,
                height: 1
            )
        }

        presenter.present(controller, animated: true)
    }

    static func makeTemporaryFile(
        markdown: String,
        suggestedName: String
    ) throws -> URL {
        let fileURL = try temporaryFileURL(
            suggestedName: suggestedName,
            pathExtension: "md"
        )
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    static func makeTemporaryFile(
        data: Data,
        suggestedName: String,
        pathExtension: String
    ) throws -> URL {
        let fileURL = try temporaryFileURL(
            suggestedName: suggestedName,
            pathExtension: pathExtension
        )
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    // Each share gets its own directory so the completion handler can delete
    // the whole thing without touching other in-flight shares.
    private static func temporaryFileURL(
        suggestedName: String,
        pathExtension: String
    ) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "MarginShare", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory.appending(
            path: "\(sanitizedFilename(suggestedName)).\(pathExtension)",
            directoryHint: .notDirectory
        )
    }

    private static func sanitizedFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:")
            .union(.controlCharacters)
        let components = name.components(separatedBy: invalidCharacters)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return components.isEmpty
            ? L10n.string("document.share.untitled")
            : components.joined(separator: "-")
    }
}
