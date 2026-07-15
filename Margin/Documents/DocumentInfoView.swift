import SwiftUI

struct DocumentInfoView: View {
    let fileURL: URL?
    let statistics: DocumentStatistics

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("文档") {
                    LabeledContent("名称", value: fileURL?.lastPathComponent ?? "未命名.md")
                    if let fileURL {
                        LabeledContent("位置", value: fileURL.deletingLastPathComponent().lastPathComponent)
                    }
                }
                Section("统计") {
                    LabeledContent("字数", value: statistics.words.formatted())
                    LabeledContent("字符", value: statistics.characters.formatted())
                    LabeledContent("行数", value: statistics.lines.formatted())
                    LabeledContent("预计阅读", value: "\(statistics.readingMinutes) 分钟")
                }
            }
            .navigationTitle("文档信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
