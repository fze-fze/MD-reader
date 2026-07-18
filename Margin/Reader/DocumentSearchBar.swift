import SwiftUI

struct DocumentSearchBar: View {
    @Bindable var session: DocumentSearchSession
    let theme: MarkdownTheme
    let onDismiss: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textSecondary)
                .accessibilityHidden(true)

            TextField("workspace.search_prompt", text: $session.query)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(session.moveToNext)

            searchStatus

            Button(action: session.moveToPrevious) {
                Label("reader.previous_match", systemImage: "chevron.up")
                    .labelStyle(.iconOnly)
                    .frame(width: 40, height: 44)
                    .contentShape(.rect)
            }
            .disabled(!session.hasMatches)
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Button(action: session.moveToNext) {
                Label("reader.next_match", systemImage: "chevron.down")
                    .labelStyle(.iconOnly)
                    .frame(width: 40, height: 44)
                    .contentShape(.rect)
            }
            .disabled(!session.hasMatches)
            .keyboardShortcut("g", modifiers: .command)

            Button(action: onDismiss) {
                Label("common.close", systemImage: "xmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .frame(width: 40, height: 44)
                    .contentShape(.rect)
            }
            .foregroundStyle(theme.textSecondary)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .frame(minHeight: 50)
        .background(theme.windowSurface, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.separator.opacity(0.7), lineWidth: 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.canvas)
        .task {
            await Task.yield()
            isFocused = true
        }
        .task(id: session.request) {
            await session.performSearch()
        }
    }

    @ViewBuilder
    private var searchStatus: some View {
        Group {
            if session.isSearching {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(L10n.string("workspace.search"))
            } else if !session.effectiveQuery.isEmpty {
                Text(session.statusText)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 54)
    }
}
