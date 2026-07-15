import SwiftUI

struct ThemeSelectionSheet: View {
    let onDone: () -> Void

    @AppStorage("readerTheme") private var selectedTheme = ReaderTheme.claude

    var body: some View {
        NavigationStack {
            ThemePickerView(selectedTheme: $selectedTheme)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成", action: onDone)
                    }
                }
        }
    }
}
