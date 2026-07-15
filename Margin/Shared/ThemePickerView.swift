import SwiftUI

struct ThemePickerView: View {
    @Binding var selectedTheme: ReaderTheme

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(ReaderTheme.allCases) { theme in
                    ThemePreviewCard(
                        theme: theme,
                        isSelected: selectedTheme == theme
                    ) {
                        selectedTheme = theme
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("选取主题")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ThemePreviewCard: View {
    let theme: ReaderTheme
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var palette: MarkdownTheme {
        MarkdownTheme(readerTheme: theme, colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                preview

                VStack(alignment: .leading, spacing: 5) {
                    Label(theme.title, systemImage: theme.systemImage)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(theme.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? palette.accent : .secondary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? palette.accent : Color.secondary.opacity(0.18), lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("选择此文稿主题")
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Aa 文稿")
                .font(MarkdownTypography.documentFont(theme: theme, size: 14, weight: .semibold))
                .foregroundStyle(palette.textStrong)
            RoundedRectangle(cornerRadius: 2)
                .fill(palette.accent)
                .frame(width: 38, height: 3)
            RoundedRectangle(cornerRadius: 2)
                .fill(palette.textSecondary.opacity(0.38))
                .frame(width: 54, height: 3)
        }
        .padding(11)
        .frame(width: 82, height: 70, alignment: .leading)
        .background(palette.canvas, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.separator))
        .accessibilityHidden(true)
    }
}
