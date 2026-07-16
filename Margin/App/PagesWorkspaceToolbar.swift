import SwiftUI

struct PagesWorkspaceToolbar: View {
    let mode: WorkspaceMode
    let accent: Color
    let canUseReaderTools: Bool
    let onSearch: () -> Void
    let onToggleMode: () -> Void
    let onSettings: () -> Void
    let onOutline: () -> Void
    let onDocumentInfo: () -> Void
    let onDocumentAction: (DocumentActionRequest) -> Void
    let canMoveOrRename: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 2) {
            Button("workspace.search", systemImage: "magnifyingglass", action: onSearch)
                .keyboardShortcut("f", modifiers: .command)
                .disabled(!canUseReaderTools)
                .frame(minWidth: 44, minHeight: 44)

            Button(
                mode == .read ? "workspace.edit" : "common.done",
                systemImage: mode == .read ? "square.and.pencil" : "checkmark.circle.fill",
                action: onToggleMode
            )
            .foregroundStyle(accent)
            .font(.title2.bold())
            .frame(minWidth: 44, minHeight: 44)

            Button("workspace.reader_settings", systemImage: "paintbrush", action: onSettings)
                .frame(minWidth: 44, minHeight: 44)

            documentMenu
                .frame(minWidth: 44, minHeight: 44)
        }
        .labelStyle(.iconOnly)
        .font(.title3)
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .padding(.horizontal, 6)
        .glassEffect(
            .regular.tint(glassTint).interactive(),
            in: .capsule
        )
    }

    private var documentMenu: some View {
        Menu("workspace.more", systemImage: "ellipsis") {
            Section {
                Button("workspace.outline", systemImage: "list.bullet.indent", action: onOutline)
                Button("workspace.document_info", systemImage: "info.circle", action: onDocumentInfo)
            }

            Section {
                Button("document.copy", systemImage: "doc.on.doc") {
                    onDocumentAction(.copy)
                }
                Button("document.move", systemImage: "folder") {
                    onDocumentAction(.move)
                }
                .disabled(!canMoveOrRename)
                Button("document.rename", systemImage: "pencil") {
                    onDocumentAction(.rename)
                }
                .disabled(!canMoveOrRename)
            }

            Section {
                Button("document.share", systemImage: "square.and.arrow.up") {
                    onDocumentAction(.share)
                }
                Button("document.print", systemImage: "printer") {
                    onDocumentAction(.print)
                }
            }
        }
    }

    private var glassTint: Color {
        colorScheme == .dark
            ? .white.opacity(0.08)
            : .white.opacity(0.18)
    }
}
