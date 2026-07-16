import SwiftUI

struct PagesDocumentNavigationBar: View {
    let mode: WorkspaceMode
    let accent: Color
    let canUseReaderTools: Bool
    let onDismiss: () -> Void
    let onSearch: () -> Void
    let onToggleMode: () -> Void
    let onSettings: () -> Void
    let onOutline: () -> Void
    let onDocumentInfo: () -> Void
    let onDocumentAction: (DocumentActionRequest) -> Void
    let canMoveOrRename: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button("workspace.back", systemImage: "chevron.backward", action: onDismiss)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .frame(minWidth: 44, minHeight: 44)
                    .glassEffect(
                        .regular.tint(glassTint).interactive(),
                        in: .circle
                    )

                Spacer(minLength: 0)

                PagesWorkspaceToolbar(
                    mode: mode,
                    accent: accent,
                    canUseReaderTools: canUseReaderTools,
                    onSearch: onSearch,
                    onToggleMode: onToggleMode,
                    onSettings: onSettings,
                    onOutline: onOutline,
                    onDocumentInfo: onDocumentInfo,
                    onDocumentAction: onDocumentAction,
                    canMoveOrRename: canMoveOrRename
                )
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(controlColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                navigationTint
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private var controlColor: Color {
        colorScheme == .dark ? .white : Color(hex: 0x262422)
    }

    private var navigationTint: Color {
        if colorScheme == .dark {
            Color(hex: 0x292724).opacity(0.58)
        } else {
            Color(hex: 0xF7F4EE).opacity(0.64)
        }
    }

    private var glassTint: Color {
        colorScheme == .dark
            ? .white.opacity(0.08)
            : .white.opacity(0.18)
    }
}
