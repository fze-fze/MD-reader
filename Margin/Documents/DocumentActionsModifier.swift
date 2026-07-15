import SwiftUI

struct DocumentActionsModifier: ViewModifier {
    let text: String
    let fileURL: URL?
    let displayName: String
    let session: DocumentSession?

    @State private var isCopyPresented = false
    @State private var isMovePresented = false
    @State private var isRenamePresented = false
    @State private var proposedName = ""
    @State private var isRenaming = false
    @State private var actionError: DocumentActionError?

    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Menu {
                        titleMenu
                    } label: {
                        Text(displayName)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("文稿操作：\(displayName)")
                }
            }
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
            .alert("重新命名", isPresented: $isRenamePresented) {
                TextField("文稿名称", text: $proposedName)
                Button("取消", role: .cancel) {}
                Button("重新命名", action: renameDocument)
                    .disabled(!DocumentRenamer.isValidName(proposedName))
            } message: {
                Text("文件扩展名会保持不变。")
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

            Button("重新命名", systemImage: "pencil", action: presentRenameDialog)
                .disabled(fileURL == nil || isRenaming)
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
                if let session {
                    try await session.rename(to: requestedName)
                } else {
                    _ = try await Task.detached(priority: .userInitiated) {
                        try DocumentRenamer.rename(fileAt: fileURL, to: requestedName)
                    }.value
                }
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
        case .copy: "无法复制文稿"
        case .move: "无法移动文稿"
        case .rename: "无法重新命名"
        case .share: "无法分享文稿"
        }
    }

    var message: String {
        switch self {
        case .copy, .move:
            "请稍后重试，或在“文件”App 中完成此操作。"
        case let .rename(error):
            error.localizedDescription
        case let .share(error):
            error.localizedDescription
        }
    }
}
