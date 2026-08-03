import SwiftUI

// A ```mermaid fence renders as a picture instead of source. The rendered
// image is memoized by MermaidRenderer, so the body reads it straight from the
// cache the way math blocks do; only a cache miss goes through the web view.
struct MermaidBlockView: View {
    let source: String
    let bodySize: Double
    let theme: MarkdownTheme
    let searchText: String
    let activeOccurrenceIndex: Int?

    @State private var diagram: MermaidRenderer.Diagram?
    @State private var failure: (any Error)?

    private var style: MermaidStyle {
        MermaidStyle(theme: theme, fontSize: bodySize)
    }

    private var renderedDiagram: MermaidRenderer.Diagram? {
        diagram ?? MermaidRenderer.shared.cachedDiagram(source: source, style: style)
    }

    // Scrolling a diagram out of the lazy stack throws this view's state away;
    // reading the renderer's memo keeps a return trip from flashing a spinner
    // or re-reporting a failure it already knows about.
    private var renderFailure: (any Error)? {
        if let failure { return failure }
        return MermaidRenderer.shared.cachedFailure(source: source, style: style)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: "MERMAID")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if renderFailure == nil {
                    DiagramExportImageButton(image: renderedDiagram?.image, theme: theme)
                } else {
                    // Nothing was drawn, so the block is plain code again.
                    CodeCopyButton(source: source, theme: theme)
                }
            }
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.codeFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.codeBorder))
        .padding(.top, 14)
        .padding(.bottom, 18)
        .accessibilityElement(children: .contain)
        .task(id: renderIdentity) { await render() }
    }

    @ViewBuilder
    private var content: some View {
        if let renderedDiagram {
            Image(uiImage: renderedDiagram.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: renderedDiagram.size.width)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 6)
                .accessibilityLabel(L10n.string("reader.mermaid.accessibility"))
        } else if let renderFailure {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(verbatim: renderFailure.localizedDescription)
                        .font(.caption)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .foregroundStyle(theme.textSecondary)

                ScrollView(.horizontal) {
                    diagramSource
                }
                .scrollIndicators(.hidden)
            }
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, minHeight: bodySize * 6)
                .accessibilityLabel(L10n.string("reader.mermaid.rendering"))
        }
    }

    private var diagramSource: some View {
        SearchablePlainText(
            source: source,
            font: .system(size: bodySize * 0.9, design: theme.codeFont),
            foregroundStyle: theme.codeText,
            theme: theme,
            searchText: searchText,
            activeOccurrenceIndex: activeOccurrenceIndex,
            occurrenceOffset: 0
        )
        .lineSpacing(bodySize * 0.39)
        .textSelection(.enabled)
        .padding(.bottom, 4)
    }

    private var renderIdentity: String {
        "\(style.identity)|\(source)"
    }

    private func render() async {
        if let cached = MermaidRenderer.shared.cachedDiagram(source: source, style: style) {
            diagram = cached
            failure = nil
            return
        }
        diagram = nil
        failure = nil

        do {
            diagram = try await MermaidRenderer.shared.diagram(source: source, style: style)
        } catch is CancellationError {
            return
        } catch {
            failure = error
        }
    }
}
