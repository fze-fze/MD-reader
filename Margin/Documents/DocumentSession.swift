import Foundation

@MainActor
@Observable
final class DocumentSession: Identifiable {
    let id = UUID()

    var text: String {
        didSet {
            guard text != oldValue else { return }
            document.replaceText(with: text, markingChanged: isOpen)
        }
    }

    private(set) var fileURL: URL
    private(set) var isRenaming = false

    private let store: DocumentSessionStore
    private var document: MarkdownUIDocument
    private var isOpen = false
    private var openTask: Task<Void, Never>?

    init(text: String, fileURL: URL, store: DocumentSessionStore) {
        self.text = text
        self.fileURL = fileURL
        self.store = store
        document = MarkdownUIDocument(fileURL: fileURL, initialText: text)
    }

    func openIfNeeded() async {
        if isOpen { return }
        if let openTask {
            await openTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            let success = await document.openDocument()
            guard success else { return }

            isOpen = true
            let diskText = document.textSnapshot
            if text == diskText {
                return
            }

            // The FileDocument value is the bootstrap source of truth. If it differs
            // because editing began while UIDocument was opening, preserve the UI text.
            document.replaceText(with: text, markingChanged: true)
        }
        openTask = task
        await task.value
        openTask = nil
    }

    func rename(to proposedName: String) async throws {
        guard !isRenaming else { return }
        isRenaming = true
        defer { isRenaming = false }

        await openIfNeeded()
        guard isOpen else {
            throw sessionError("文稿尚未准备好，请稍后重试。")
        }

        let sourceURL = fileURL
        try await saveCurrentDocument()
        try await closeCurrentDocument()

        do {
            let destinationURL = try await Task.detached(priority: .userInitiated) {
                try DocumentRenamer.rename(fileAt: sourceURL, to: proposedName)
            }.value

            guard destinationURL.standardizedFileURL != sourceURL.standardizedFileURL else {
                try await reopenDocument(at: sourceURL)
                return
            }

            store.registerMove(of: self, from: sourceURL, to: destinationURL)
            fileURL = destinationURL
            try await reopenDocument(at: destinationURL)
        } catch {
            let recoveryURL = FileManager.default.fileExists(atPath: sourceURL.path())
                ? sourceURL
                : fileURL
            try? await reopenDocument(at: recoveryURL)
            throw error
        }
    }

    private func saveCurrentDocument() async throws {
        document.replaceText(with: text, markingChanged: true)
        guard await document.saveDocument(to: fileURL) else {
            throw sessionError("保存当前修改时出现问题，文稿尚未重新命名。")
        }
    }

    private func closeCurrentDocument() async throws {
        guard await document.closeDocument() else {
            throw sessionError("关闭旧文件会话时出现问题，文稿尚未重新命名。")
        }
        isOpen = false
    }

    private func reopenDocument(at url: URL) async throws {
        let replacement = MarkdownUIDocument(fileURL: url, initialText: text)
        guard await replacement.openDocument() else {
            throw sessionError("无法在新位置重新打开文稿。")
        }
        replacement.replaceText(with: text, markingChanged: false)
        document = replacement
        fileURL = url
        isOpen = true
    }

    private func sessionError(_ message: String) -> NSError {
        NSError(
            domain: "com.fze.margin.document-session",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

private extension MarkdownUIDocument {
    func openDocument() async -> Bool {
        await withCheckedContinuation { continuation in
            open { success in
                continuation.resume(returning: success)
            }
        }
    }

    func closeDocument() async -> Bool {
        await withCheckedContinuation { continuation in
            close { success in
                continuation.resume(returning: success)
            }
        }
    }

    func saveDocument(to url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            save(to: url, for: .forOverwriting) { success in
                continuation.resume(returning: success)
            }
        }
    }
}
