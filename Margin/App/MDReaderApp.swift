import SwiftUI

@main
struct MDReaderApp: App {
    @UIApplicationDelegateAdaptor(MarginAppDelegate.self) private var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            DocumentWorkspaceView(
                text: file.$document.text,
                fileURL: file.fileURL
            )
        }

        DocumentGroupLaunchScene("Margin 文稿") {
            ThemeSelectionButton()
            NewDocumentButton("开始书写", for: MarkdownDocument.self)
        } background: {
            MarginLaunchBackground()
        }
    }
}
