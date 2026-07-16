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

        DocumentGroupLaunchScene(
            Text("launch.documents")
                .font(.largeTitle.scaled(by: 1.2))
                .bold()
        ) {
            ThemeSelectionButton()
            NewDocumentButton("launch.start_writing", for: MarkdownDocument.self)
        } background: {
            MarginLaunchBackground()
        }
    }
}
