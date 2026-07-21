import Foundation

enum DocumentExportFormat: Equatable, CaseIterable {
    case markdown
    case pdf
    case html

    var pathExtension: String {
        switch self {
        case .markdown: "md"
        case .pdf: "pdf"
        case .html: "html"
        }
    }
}
