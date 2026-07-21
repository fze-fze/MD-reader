import Foundation
import UIKit
import WebKit

@MainActor
enum DocumentPDFExporter {
    // A4 at 72 dpi. The margin mirrors the print stylesheet's @page rule
    // (~17mm) so exported PDFs match what the print preview shows.
    private static let paperSize = CGSize(width: 595.2, height: 841.8)
    private static let pageMargin: CGFloat = 48

    static func export(
        text: String,
        title: String,
        theme: ReaderTheme,
        baseURL: URL?
    ) async throws {
        let data = try await pdfData(
            text: text,
            title: title,
            theme: theme,
            baseURL: baseURL
        )
        let fileURL = try DocumentSharePresenter.makeTemporaryFile(
            data: data,
            suggestedName: title,
            pathExtension: "pdf"
        )
        try await DocumentSharePresenter.present(fileAt: fileURL)
    }

    static func pdfData(
        text: String,
        title: String,
        theme: ReaderTheme,
        baseURL: URL?
    ) async throws -> Data {
        let html = MarkdownPrintRenderer.html(
            source: text,
            title: title,
            theme: theme,
            baseURL: baseURL
        )

        let paperRect = CGRect(origin: .zero, size: paperSize)
        let printableRect = paperRect.insetBy(dx: pageMargin, dy: pageMargin)

        // Formulas and task markers are embedded as base64 data: URIs.
        // UIMarkupTextPrintFormatter paginates before those images finish
        // loading, which drops them from the output — so render the HTML in a
        // real web view first and paginate that once it reports done.
        let webView = WKWebView(frame: CGRect(origin: .zero, size: printableRect.size))
        webView.isOpaque = false
        let loader = NavigationLoader()
        webView.navigationDelegate = loader

        let host = AppPresentationAnchor.rootViewController?.view
        if let host {
            webView.alpha = 0
            host.addSubview(webView)
        }
        defer { webView.removeFromSuperview() }

        webView.loadHTMLString(html, baseURL: baseURL)
        try await loader.waitForLoad()

        let pageRenderer = UIPrintPageRenderer()
        pageRenderer.addPrintFormatter(
            webView.viewPrintFormatter(),
            startingAtPageAt: 0
        )
        // UIPrintPageRenderer exposes these as read-only; the print system
        // normally fills them in. Paginating outside a print job means
        // supplying the page geometry ourselves.
        pageRenderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        pageRenderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

        let pageCount = pageRenderer.numberOfPages
        guard pageCount > 0 else { throw exportError() }

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: title]

        let data = UIGraphicsPDFRenderer(bounds: paperRect, format: format)
            .pdfData { context in
                pageRenderer.prepare(
                    forDrawingPages: NSRange(location: 0, length: pageCount)
                )
                for pageIndex in 0..<pageCount {
                    context.beginPage()
                    pageRenderer.drawPage(at: pageIndex, in: paperRect)
                }
            }

        guard !data.isEmpty else { throw exportError() }
        return data
    }

    private static func exportError() -> NSError {
        NSError(
            domain: "com.fze.margin.pdf-export",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: L10n.string("document.error.export_failed")
            ]
        )
    }

    @MainActor
    private final class NavigationLoader: NSObject, WKNavigationDelegate {
        private var continuation: CheckedContinuation<Void, any Error>?
        private var hasFinished = false

        func waitForLoad() async throws {
            if hasFinished { return }
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                // Never hang the export if the web view goes silent.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(10))
                    self.finish(with: nil)
                }
            }
            // Layout of the just-decoded images lands on the next runloop
            // turns; give the web view a beat before paginating it.
            try await Task.sleep(for: .milliseconds(120))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            finish(with: nil)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: any Error
        ) {
            finish(with: error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: any Error
        ) {
            finish(with: error)
        }

        private func finish(with error: (any Error)?) {
            guard !hasFinished else { return }
            hasFinished = true
            let continuation = self.continuation
            self.continuation = nil
            if let error {
                continuation?.resume(throwing: error)
            } else {
                continuation?.resume()
            }
        }
    }
}
