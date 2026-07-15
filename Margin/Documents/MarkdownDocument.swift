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

    static var starterDocument: String {
        guard let url = Bundle.main.url(
            forResource: "DefaultDocument",
            withExtension: "md"
        ), let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return "# Margin\n"
        }
        return contents
    }
}
