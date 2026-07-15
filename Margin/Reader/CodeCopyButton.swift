import SwiftUI
import UIKit

struct CodeCopyButton: View {
    let source: String
    let theme: MarkdownTheme

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCopied = false
    @State private var copyCount = 0

    var body: some View {
        Button(action: copySource) {
            HStack(spacing: 6) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))

                if isCopied {
                    Text("已复制")
                        .font(.caption)
                        .transition(successTextTransition)
                }
            }
            .padding(.horizontal, isCopied ? 8 : 0)
            .frame(minWidth: isCopied ? nil : 28, minHeight: 28)
            .background(
                isCopied ? theme.accent.opacity(0.12) : .clear,
                in: .rect(cornerRadius: 6)
            )
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isCopied ? theme.accent : theme.textSecondary)
        .accessibilityLabel(isCopied ? "复制成功" : "复制代码")
        .accessibilityHint(isCopied ? "代码已复制到剪贴板" : "将代码复制到剪贴板")
        .sensoryFeedback(.success, trigger: copyCount)
        .task(id: copyCount) {
            guard copyCount > 0 else { return }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            withAnimation(feedbackAnimation) {
                isCopied = false
            }
        }
    }

    private var feedbackAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .snappy(duration: 0.22, extraBounce: 0.08)
    }

    private var successTextTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.92, anchor: .trailing))
    }

    private func copySource() {
        UIPasteboard.general.string = source
        copyCount &+= 1
        withAnimation(feedbackAnimation) {
            isCopied = true
        }
    }
}
