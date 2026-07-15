import Foundation

enum DocumentShareError: LocalizedError {
    case noActiveWindow

    var errorDescription: String? {
        switch self {
        case .noActiveWindow:
            L10n.string("document.error.no_share_window")
        }
    }
}
