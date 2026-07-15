import SwiftUI

struct DocumentActionsModifier: ViewModifier {
    let text: String
    let fileURL: URL?
    let displayName: String

    @State private var isCopyPresented = false
    @State private var isMovePresented = false
    @State private var actionError: DocumentActionError?

    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .toolbarTitleMenu { titleMenu }
            .fileExporter(
                isPresented: $isCopyPresented,
                document: MarkdownDocument(text: text),
                contentTypes: [MarkdownDocument.markdownContentType],
                defaultFilename: "\(displayName) 副本"
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
            .alert(item: $actionError) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("好"))
                )
            }
    }

    @ViewBuilder
    private var titleMenu: some View {
        Section {
            Button("复制", systemImage: "doc.on.doc") {
                isCopyPresented = true
            }

            if fileURL != nil {
                Button("移动", systemImage: "folder") {
                    isMovePresented = true
                }
            }

            DocumentRenameMenuItem()
        }

        Section {
            Button("分享", systemImage: "square.and.arrow.up") {
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
        }

        Section {
            Button("打印", systemImage: "printer") {
                DocumentPrinter.present(
                    text: text,
                    title: displayName,
                    baseURL: fileURL?.deletingLastPathComponent()
                )
            }
        }
    }
}

private enum DocumentActionError: Identifiable {
    case copy(Error)
    case move(Error)
    case share(Error)

    var id: String {
        switch self {
        case .copy: "copy"
        case .move: "move"
        case .share: "share"
        }
    }

    var title: String {
        switch self {
        case .copy: "无法复制文稿"
        case .move: "无法移动文稿"
        case .share: "无法分享文稿"
        }
    }

    var message: String {
        switch self {
        case .copy, .move:
            "请稍后重试，或在“文件”App 中完成此操作。"
        case let .share(error):
            error.localizedDescription
        }
    }
}
