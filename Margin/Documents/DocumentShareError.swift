import Foundation

enum DocumentShareError: LocalizedError {
    case noActiveWindow

    var errorDescription: String? {
        switch self {
        case .noActiveWindow:
            "找不到可用于显示分享面板的窗口。"
        }
    }
}
