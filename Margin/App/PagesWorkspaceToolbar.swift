import SwiftUI

struct PagesWorkspaceToolbar: View {
    let mode: WorkspaceMode
    let accent: Color
    let glassTint: Color
    let canUseReaderTools: Bool
    let onSearch: () -> Void
    let onToggleMode: () -> Void
    let onSettings: () -> Void
    let onOutline: () -> Void
    let onDocumentInfo: () -> Void
    let onDocumentAction: (DocumentActionRequest) -> Void
    let canMoveOrRename: Bool

    var body: some View {
        HStack(spacing: 2) {
            // A Button's tap target is its label, so the 44pt frame (and the
            // hit shape covering it) must live inside the label — outside the
            // button it only reserves layout space around a glyph-sized target.
            Button(action: onSearch) {
                Label("workspace.search", systemImage: "magnifyingglass")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(!canUseReaderTools)

            Button(action: onToggleMode) {
                Label(
                    mode == .read ? "workspace.edit" : "common.done",
                    systemImage: mode == .read ? "square.and.pencil" : "checkmark.circle.fill"
                )
                .font(.title2.bold())
                .frame(width: 44, height: 44)
                .contentShape(.rect)
            }
            .foregroundStyle(accent)

            Button(action: onSettings) {
                Label("workspace.reader_settings", systemImage: "paintbrush")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }

            documentMenu
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
        Menu {
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
        } label: {
            Label("workspace.more", systemImage: "ellipsis")
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
    }
}
