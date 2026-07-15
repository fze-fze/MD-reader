import Foundation
import UIKit

enum HomeScreenQuickAction {
    static let newMarkdownDocument = "com.fze.margin.new-markdown-document"

    static func handles(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard shortcutItem.type == newMarkdownDocument else { return false }
        QuickActionDocumentCreator.createAndOpenBlankDocument()
        return true
    }
}

@MainActor
enum QuickActionDocumentCreator {
    private static let pendingEditorPathKey = "quickActionPendingEditorPath"

    static func createAndOpenBlankDocument() {
        do {
            let url = try nextDocumentURL()
            try Data().write(to: url, options: .atomic)
            UserDefaults.standard.set(url.path, forKey: pendingEditorPathKey)
            UIApplication.shared.open(url) { opened in
                if !opened {
                    UserDefaults.standard.removeObject(forKey: pendingEditorPathKey)
                }
            }
        } catch {
            assertionFailure("Quick action document creation failed: \(error.localizedDescription)")
        }
    }

    static func consumeEditorRequest(for fileURL: URL?) -> Bool {
        guard let fileURL,
              let pendingPath = UserDefaults.standard.string(forKey: pendingEditorPathKey),
              fileURL.standardizedFileURL.path == URL(fileURLWithPath: pendingPath).standardizedFileURL.path else {
            return false
        }
        UserDefaults.standard.removeObject(forKey: pendingEditorPathKey)
        return true
    }

    private static func nextDocumentURL() throws -> URL {
        let folder = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        for index in 1...9_999 {
            let suffix = index == 1 ? "" : " \(index)"
            let baseName = L10n.string("quick_action.default_filename")
            let candidate = folder.appendingPathComponent("\(baseName)\(suffix).md")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        throw CocoaError(.fileWriteFileExists)
    }
}
