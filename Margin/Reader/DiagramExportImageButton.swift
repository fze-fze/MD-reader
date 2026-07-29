import SwiftUI
import UIKit

// Takes the place of the code block's copy button on a rendered diagram:
// copying mermaid source is rarely what a reader wants, the picture is.
struct DiagramExportImageButton: View {
    let image: UIImage?
    let theme: MarkdownTheme

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var state: ExportState = .idle
    @State private var attemptCount = 0

    private enum ExportState: Equatable {
        case idle
        case exporting
        case failed
    }

    var body: some View {
        Button(action: export) {
            HStack(spacing: 5) {
                icon
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 28)
            .background(
                state == .failed ? theme.codeBorder.opacity(0.5) : .clear,
                in: .rect(cornerRadius: 6)
            )
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(image == nil ? theme.textSecondary.opacity(0.5) : theme.textSecondary)
        .disabled(image == nil || state == .exporting)
        .accessibilityLabel(L10n.string("reader.export_image"))
        .accessibilityHint(L10n.string("reader.export_image_hint"))
        .sensoryFeedback(trigger: attemptCount) { _, count in
            guard count > 0 else { return nil }
            return state == .failed ? .error : .success
        }
        .task(id: attemptCount) {
            guard state == .failed else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(feedbackAnimation) { state = .idle }
        }
    }

    private var title: LocalizedStringKey {
        state == .failed ? "reader.export_image_failed" : "reader.export_image"
    }

    @ViewBuilder
    private var icon: some View {
        if state == .exporting {
            ProgressView()
                .controlSize(.mini)
        } else {
            Image(systemName: state == .failed ? "exclamationmark.triangle" : "square.and.arrow.up")
                .contentTransition(.symbolEffect(.replace))
        }
    }

    private var feedbackAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .snappy(duration: 0.22, extraBounce: 0.08)
    }

    private func export() {
        guard let image, state != .exporting else { return }
        // The picture is drawn over the code block's own fill so the exported
        // file reads the same way in an app that assumes a white background.
        let background = UIColor(theme.codeFill)
        withAnimation(feedbackAnimation) { state = .exporting }

        Task { @MainActor in
            do {
                let data = try DiagramImageExporter.pngData(
                    for: image,
                    background: background
                )
                let fileURL = try DocumentSharePresenter.makeTemporaryFile(
                    data: data,
                    suggestedName: L10n.string("reader.mermaid.export_filename"),
                    pathExtension: "png"
                )
                try await DocumentSharePresenter.present(fileAt: fileURL)
                withAnimation(feedbackAnimation) { state = .idle }
            } catch {
                withAnimation(feedbackAnimation) { state = .failed }
            }
            attemptCount &+= 1
        }
    }
}

enum DiagramImageExporter {
    static let padding: CGFloat = 20

    static func pngData(for image: UIImage, background: UIColor) throws -> Data {
        let size = CGSize(
            width: image.size.width + padding * 2,
            height: image.size.height + padding * 2
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = max(image.scale, 2)
        format.opaque = true

        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(at: CGPoint(x: padding, y: padding))
        }

        guard let data = rendered.pngData() else {
            throw MermaidRenderFailure.renderFailed
        }
        return data
    }
}
