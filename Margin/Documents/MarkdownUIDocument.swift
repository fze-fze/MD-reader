import UIKit

final class MarkdownUIDocument: UIDocument {
    private let contentLock = NSLock()
    private var storedText: String

    init(fileURL url: URL, initialText: String) {
        storedText = initialText
        super.init(fileURL: url)
    }

    var textSnapshot: String {
        contentLock.withLock { storedText }
    }

    func replaceText(with text: String, markingChanged: Bool) {
        contentLock.withLock {
            storedText = text
        }
        if markingChanged {
            updateChangeCount(.done)
        }
    }

    override nonisolated func load(
        fromContents contents: Any,
        ofType typeName: String?
    ) throws {
        let data: Data
        if let fileData = contents as? Data {
            data = fileData
        } else if let wrapper = contents as? FileWrapper,
                  let fileData = wrapper.regularFileContents {
            data = fileData
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let decodedText: String
        if let text = String(data: data, encoding: .utf8) {
            decodedText = text
        } else if let text = String(data: data, encoding: .utf16) {
            decodedText = text
        } else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }

        contentLock.withLock {
            storedText = decodedText
        }
    }

    override nonisolated func contents(forType typeName: String) throws -> Any {
        let text = contentLock.withLock { storedText }
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return data
    }
}
