import SwiftUI

struct DocumentActionsModifier: ViewModifier {
    let text: String
    let fileURL: URL?
    let displayName: String
    @Binding var requestedAction: DocumentActionRequest?

    @State private var isCopyPresented = false
    @State private var isMovePresented = false
    @State private var isRenamePresented = false
    @State private var proposedName = ""
    @State private var isRenaming = false
    @State private var actionError: DocumentActionError?

    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .fileExporter(
                isPresented: $isCopyPresented,
                document: MarkdownDocument(text: text),
                contentTypes: [MarkdownDocument.markdownContentType],
                defaultFilename: L10n.format("document.copy_filename", displayName)
            ) { result in
                if case let .failure(error) = result {
                    actionError = .copy(error)
                }
            } onCancellation: {
                // The system dismisses the exporter without changing the document.
            }
            .fileMover(
                isPresented: $isMovePresented,
                file: fileURL
            ) { result in
                switch result {
                case .success:
                    dismiss()
                case let .failure(error):
                    actionError = .move(error)
                }
            } onCancellation: {
                // The current document remains open at its original location.
            }
            .alert("document.rename", isPresented: $isRenamePresented) {
                TextField("document.name_field", text: $proposedName)
                Button("common.cancel", role: .cancel) {}
                Button("document.rename", action: renameDocument)
                    .disabled(!DocumentRenamer.isValidName(proposedName))
            } message: {
                Text("document.extension_unchanged")
            }
            .alert(item: $actionError) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("common.ok"))
                )
            }
            .onChange(of: requestedAction) { _, request in
                guard let request else { return }
                requestedAction = nil
                perform(request)
            }
    }

    private func perform(_ request: DocumentActionRequest) {
        switch request {
        case .copy:
            isCopyPresented = true
        case .move:
            guard fileURL != nil else { return }
            isMovePresented = true
        case .rename:
            guard fileURL != nil, !isRenaming else { return }
            presentRenameDialog()
        case .share:
            shareDocument()
        case .print:
            DocumentPrinter.present(
                text: text,
                title: displayName,
                baseURL: fileURL?.deletingLastPathComponent()
            )
        }
    }

    private func shareDocument() {
        Task { @MainActor in
            do {
                try await DocumentSharePresenter.present(
                    markdown: text,
                    suggestedName: displayName
                )
            } catch {
                actionError = .share(error)
            }
        }
    }

    private func presentRenameDialog() {
        proposedName = displayName
        isRenamePresented = true
    }

    private func renameDocument() {
        guard let fileURL else { return }
        let requestedName = proposedName
        isRenaming = true
        Task {
            do {
                _ = try await Task.detached(priority: .userInitiated) {
                    try DocumentRenamer.rename(fileAt: fileURL, to: requestedName)
                }.value
                isRenaming = false
            } catch {
                isRenaming = false
                actionError = .rename(error)
            }
        }
    }
}

private enum DocumentActionError: Identifiable {
    case copy(Error)
    case move(Error)
    case rename(Error)
    case share(Error)

    var id: String {
        switch self {
        case .copy: "copy"
        case .move: "move"
        case .rename: "rename"
        case .share: "share"
        }
    }

    var title: String {
        switch self {
        case .copy: L10n.string("document.error.copy_title")
        case .move: L10n.string("document.error.move_title")
        case .rename: L10n.string("document.error.rename_title")
        case .share: L10n.string("document.error.share_title")
        }
    }

    var message: String {
        switch self {
        case .copy, .move:
            L10n.string("document.error.files_retry")
        case let .rename(error):
            error.localizedDescription
        case let .share(error):
            error.localizedDescription
        }
    }
}
