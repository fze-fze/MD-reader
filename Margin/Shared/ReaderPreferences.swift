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
    case live
    case source

    var id: Self { self }
    var isEditing: Bool { self != .read }

    var title: LocalizedStringKey {
        switch self {
        case .read: "workspace.mode.read"
        case .live: "workspace.mode.live"
        case .source: "workspace.mode.source"
        }
    }

    var accessibilityTitle: LocalizedStringKey { self == .live ? "editor.live_formatting" : title }
}
