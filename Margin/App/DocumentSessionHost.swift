import SwiftUI

struct DocumentSessionHost: View {
    @Binding private var bootstrapText: String
    private let sourceURL: URL?

    init(bootstrapText: Binding<String>, sourceURL: URL?) {
        _bootstrapText = bootstrapText
        self.sourceURL = sourceURL
    }

    var body: some View {
        if let sourceURL {
            SessionWorkspace(
                session: DocumentSessionStore.shared.session(
                    for: sourceURL,
                    bootstrapText: bootstrapText
                )
            )
        } else {
            DocumentWorkspaceView(
                text: $bootstrapText,
                fileURL: nil
            )
        }
    }
}

private struct SessionWorkspace: View {
    let session: DocumentSession

    var body: some View {
        DocumentWorkspaceView(session: session)
            .task {
                await session.openIfNeeded()
            }
    }
}
