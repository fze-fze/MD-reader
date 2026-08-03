import SwiftUI

/// The app's own controls inside the system document navigation bar.
///
/// The bar, the back button, and the file-name title menu are DocumentGroup's
/// (`.toolbarRole(.editor)` gives them the Pages-style editor layout) — the same
/// chrome `UIDocumentViewController` builds from the open document. Everything
/// here is what Margin adds on the trailing side, so nothing depends on what
/// the system title menu happens to contain.
struct WorkspaceToolbarContent: ToolbarContent {
    let mode: WorkspaceMode
    let documentName: String
    let onSearch: () -> Void
    let onToggleMode: () -> Void
    let onSettings: () -> Void
    let onOutline: () -> Void
    let onDocumentInfo: () -> Void
    let onDocumentAction: (DocumentActionRequest) -> Void
    let canMove: Bool
    let canRename: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onSearch) {
                Label("workspace.search", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: .command)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onToggleMode) {
                Label(
                    mode == .read ? "workspace.edit" : "common.done",
                    systemImage: mode == .read ? "square.and.pencil" : "checkmark.circle.fill"
                )
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            documentMenu
        }
    }

    // Reading and file actions live here rather than in the title menu: that
    // menu is the system's, built from the open document, and overriding it
    // would trade away rename, drag, and the document header preview.
    private var documentMenu: some View {
        Menu {
            Section {
                Button("workspace.outline", systemImage: "list.bullet.indent", action: onOutline)
                Button("workspace.document_info", systemImage: "info.circle", action: onDocumentInfo)
                Button("workspace.reader_settings", systemImage: "paintbrush", action: onSettings)
            }

            Section {
                Button("document.copy", systemImage: "doc.on.doc") {
                    onDocumentAction(.copy)
                }
                Button("document.move", systemImage: "folder") {
                    onDocumentAction(.move)
                }
                .disabled(!canMove)
                Button("document.rename", systemImage: "pencil") {
                    onDocumentAction(.rename)
                }
                .disabled(!canRename)
            }

            Section {
                Menu("document.export", systemImage: "square.and.arrow.up") {
                    Button("document.export.markdown", systemImage: "doc.plaintext") {
                        onDocumentAction(.export(.markdown))
                    }
                    Button("document.export.pdf", systemImage: "doc.richtext") {
                        onDocumentAction(.export(.pdf))
                    }
                    Button("document.export.html", systemImage: "chevron.left.forwardslash.chevron.right") {
                        onDocumentAction(.export(.html))
                    }
                }
                Button("document.print", systemImage: "printer") {
                    onDocumentAction(.print)
                }
            }
        } label: {
            Label("workspace.more", systemImage: "ellipsis")
        }
        .accessibilityLabel(L10n.format("workspace.document_menu_accessibility", documentName))
    }
}
