import SwiftUI

struct DocumentRenameMenuItem: View {
    @Environment(\.rename) private var rename

    var body: some View {
        Button("重新命名", systemImage: "pencil", action: renameDocument)
            .disabled(rename == nil)
    }

    private func renameDocument() {
        rename?()
    }
}
