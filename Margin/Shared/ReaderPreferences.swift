import SwiftUI

enum ReaderAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum WorkspaceMode: String, CaseIterable, Identifiable {
    case read
    case edit

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .read: "阅读"
        case .edit: "编辑"
        }
    }

    var systemImage: String {
        switch self {
        case .read: "doc.richtext"
        case .edit: "pencil.line"
        }
    }
}
