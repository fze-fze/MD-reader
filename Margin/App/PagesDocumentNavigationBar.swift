import SwiftUI

struct PagesDocumentNavigationBar: View {
    @Binding var mode: WorkspaceMode
    let documentName: String
    let theme: MarkdownTheme
    let onDismiss: () -> Void
    let onSearch: () -> Void
    let onSettings: () -> Void
    let onOutline: () -> Void
    let onDocumentInfo: () -> Void
    let onDocumentAction: (DocumentActionRequest) -> Void
    let canMove: Bool
    let canRename: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 8) {
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

                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        modePicker(withFullLabels: true)
                            .pickerStyle(.menu)
                    } else {
                        modePicker(withFullLabels: false)
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 280)
                    }
                }
                .frame(maxWidth: .infinity)

                PagesWorkspaceToolbar(
                    documentName: documentName,
                    glassTint: theme.navigationGlassTint,
                    onSearch: onSearch,
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
        // No bar chrome: the document fades out under the floating glass
        // controls instead of being cut off by an opaque band.
        .background {
            LinearGradient(
                stops: [
                    .init(color: theme.canvas, location: 0),
                    .init(color: theme.canvas.opacity(0.94), location: 0.7),
                    .init(color: theme.canvas.opacity(0.5), location: 0.86),
                    .init(color: theme.canvas.opacity(0), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .padding(.bottom, -24)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }

    private func modePicker(withFullLabels: Bool) -> some View {
        Picker("workspace.mode.label", selection: $mode) {
            ForEach(WorkspaceMode.allCases) { mode in
                Text(withFullLabels ? mode.accessibilityTitle : mode.title)
                    .accessibilityLabel(Text(mode.accessibilityTitle))
                    .tag(mode)
            }
        }
        .tint(theme.accent)
        .frame(minHeight: 44)
    }
}
