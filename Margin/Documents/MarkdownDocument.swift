import SwiftUI
import UniformTypeIdentifiers

struct MarkdownDocument: FileDocument {
    static let markdownContentType = UTType(
        importedAs: "net.daringfireball.markdown",
        conformingTo: .plainText
    )

    static let readableContentTypes: [UTType] = [markdownContentType, .plainText]
    static let writableContentTypes: [UTType] = [markdownContentType, .plainText]

    var text: String

    init(text: String = Self.starterDocument) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        if let decoded = String(data: data, encoding: .utf8) {
            text = decoded
        } else if let decoded = String(data: data, encoding: .utf16) {
            text = decoded
        } else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }

    static let starterDocument = """
    # 欢迎使用 Margin

    一处安静、原生的 Markdown 阅读与写作空间。

    > 打开一个文档，或直接从这里开始。你的修改会由系统自动保存。

    ## 你可以做什么

    - 在阅读和编辑间自然切换
    - 使用 **Markdown** 组织想法
    - 在 iPhone、iPad 与“文件”App 之间原位打开文档

    ```swift
    let writing = "清晰，也可以很漂亮"
    ```
    """
}
