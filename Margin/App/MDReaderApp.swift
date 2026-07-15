import SwiftUI

@main
struct MDReaderApp: App {
    @UIApplicationDelegateAdaptor(MarginAppDelegate.self) private var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            DocumentSessionHost(
                bootstrapText: file.$document.text,
                sourceURL: file.fileURL
            )
        }

        DocumentGroupLaunchScene("launch.documents") {
            ThemeSelectionButton()
            NewDocumentButton("launch.start_writing", for: MarkdownDocument.self)
        } background: {
            MarginLaunchBackground()
        }
    }
}
