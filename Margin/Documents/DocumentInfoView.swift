import SwiftUI

struct DocumentInfoView: View {
    let fileURL: URL?
    let statistics: DocumentStatistics

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("document.section.document") {
                    LabeledContent(
                        "document.name",
                        value: fileURL?.lastPathComponent ?? L10n.string("document.untitled_filename")
                    )
                    if let fileURL {
                        LabeledContent(
                            "document.location",
                            value: fileURL.deletingLastPathComponent().lastPathComponent
                        )
                    }
                }
                Section("document.section.statistics") {
                    LabeledContent("document.words", value: statistics.words.formatted())
                    LabeledContent("document.characters", value: statistics.characters.formatted())
                    LabeledContent("document.lines", value: statistics.lines.formatted())
                    LabeledContent(
                        "document.estimated_reading",
                        value: L10n.format(
                            "document.reading_minutes",
                            Int64(statistics.readingMinutes)
                        )
                    )
                }
            }
            .navigationTitle("document.info.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
