import SwiftUI

enum ReaderAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .system: "appearance.system"
        case .light: "appearance.light"
        case .dark: "appearance.dark"
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
        case .read: "workspace.mode.read"
        case .edit: "workspace.mode.edit"
        }
    }

    var systemImage: String {
        switch self {
        case .read: "doc.richtext"
        case .edit: "pencil.line"
        }
    }
}
