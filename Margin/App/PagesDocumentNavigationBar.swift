import SwiftUI

struct PagesDocumentNavigationBar: View {
    let mode: WorkspaceMode
    let theme: MarkdownTheme
    let canUseReaderTools: Bool
    let onDismiss: () -> Void
    let onSearch: () -> Void
    let onToggleMode: () -> Void
    let onSettings: () -> Void
    let onOutline: () -> Void
    let onDocumentInfo: () -> Void
    let onDocumentAction: (DocumentActionRequest) -> Void
    let canMove: Bool
    let canRename: Bool

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Label("workspace.back", systemImage: "chevron.backward")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .glassEffect(
                    .regular.tint(theme.navigationGlassTint).interactive(),
                    in: .circle
                )

                Spacer(minLength: 0)

                PagesWorkspaceToolbar(
                    mode: mode,
                    accent: theme.accent,
                    glassTint: theme.navigationGlassTint,
                    canUseReaderTools: canUseReaderTools,
                    onSearch: onSearch,
                    onToggleMode: onToggleMode,
                    onSettings: onSettings,
                    onOutline: onOutline,
                    onDocumentInfo: onDocumentInfo,
                    onDocumentAction: onDocumentAction,
                    canMove: canMove,
                    canRename: canRename
                )
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.navigationControl)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                theme.navigationSurface
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}
