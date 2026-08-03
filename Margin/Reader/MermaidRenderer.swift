import SwiftUI
import UIKit
import WebKit

// Everything a diagram can fail at reads the same way to the reader: the block
// falls back to its source. Only a syntax complaint from mermaid carries a
// message worth showing.
nonisolated enum MermaidRenderFailure: LocalizedError, Equatable {
    case unavailable
    case invalidDiagram(String)
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .unavailable, .renderFailed:
            L10n.string("reader.mermaid.error")
        case let .invalidDiagram(message):
            message.isEmpty ? L10n.string("reader.mermaid.error") : message
        }
    }
}

// Mermaid has no native Swift renderer, so diagrams go through the bundled
// mermaid.js running in one offscreen web view: the JS lays the diagram out and
// reports its intrinsic size, the web view is snapshotted at that size, and the
// resulting image is cached like a math formula. The reader then draws a plain
// `Image`, so scrolling never pays for a live web view per code block.
@MainActor
final class MermaidRenderer {
    static let shared = MermaidRenderer()

    struct Diagram {
        let image: UIImage
        // Natural size in points; the image itself is at screen scale.
        let size: CGSize
    }

    typealias Failure = MermaidRenderFailure

    // Content-sized diagrams ignore the viewport, but the ones that fill their
    // container (gantt, timeline) take its width — 960 keeps those readable
    // once the reader scales them down to its column.
    private let renderViewportSize = CGSize(width: 960, height: 960)
    // Far enough left that no part of the render view overlaps the window on any
    // device, so it never shows through the app's own content.
    private var offscreenOrigin: CGPoint {
        CGPoint(x: -renderViewportSize.width, y: 0)
    }
    private let maximumDiagramDimension: CGFloat = 2_600
    private let cacheLimit = 24

    private var webView: WKWebView?
    private var loadTask: Task<WKWebView, any Error>?
    private var cache: [String: Diagram] = [:]
    private var failures: [String: Failure] = [:]
    private var renderTasks: [String: Task<Diagram, any Error>] = [:]
    // One stage element is shared by every render, so renders run one at a time.
    private var queue: Task<Void, Never>?

    private init() {}

    func cachedDiagram(source: String, style: MermaidStyle) -> Diagram? {
        cache[cacheKey(source: source, style: style)]
    }

    func cachedFailure(source: String, style: MermaidStyle) -> Failure? {
        failures[cacheKey(source: source, style: style)]
    }

    func diagram(source: String, style: MermaidStyle) async throws -> Diagram {
        let key = cacheKey(source: source, style: style)
        if let cached = cache[key] { return cached }
        if let failure = failures[key] { throw failure }
        if let existing = renderTasks[key] { return try await existing.value }

        let previous = queue
        let task = Task { @MainActor [weak self] () async throws -> Diagram in
            if let previous { await previous.value }
            guard let self else { throw Failure.unavailable }
            defer { self.renderTasks[key] = nil }
            do {
                let diagram = try await self.render(source: source, style: style)
                self.store(diagram, forKey: key)
                return diagram
            } catch let failure as Failure {
                // Only a diagram mermaid refuses to parse stays refused. A
                // missing window or a snapshot that came back empty is
                // circumstance, and the block should try again next time.
                if case .invalidDiagram = failure { self.failures[key] = failure }
                throw failure
            } catch {
                throw Failure.renderFailed
            }
        }
        renderTasks[key] = task
        queue = Task { _ = try? await task.value }
        return try await task.value
    }

    // Print and PDF build their HTML synchronously, so every diagram they need
    // has to be in the cache before the renderer runs. Failures stay silent:
    // a block without a picture prints as its source, which is the fallback
    // the HTML already has.
    func prepare(sources: [String], style: MermaidStyle) async {
        for source in sources where cachedDiagram(source: source, style: style) == nil {
            _ = try? await diagram(source: source, style: style)
        }
    }

    // Derived data, all of it rebuildable: hand it back when memory is tight,
    // web view included — mermaid.js alone is several megabytes of parsed script.
    func purge() {
        cache.removeAll()
        failures.removeAll()
        webView?.removeFromSuperview()
        webView = nil
        loadTask = nil
    }

    private func store(_ diagram: Diagram, forKey key: String) {
        if cache.count >= cacheLimit { cache.removeAll() }
        cache[key] = diagram
    }

    private func cacheKey(source: String, style: MermaidStyle) -> String {
        "\(style.identity)|\(source)"
    }

    private func render(source: String, style: MermaidStyle) async throws -> Diagram {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.invalidDiagram("") }

        let webView = try await readyWebView()
        webView.frame = CGRect(origin: offscreenOrigin, size: renderViewportSize)

        let theme = MarkdownTheme(readerTheme: style.readerTheme, colorScheme: style.colorScheme)
        let configuration = mermaidConfiguration(style: style, theme: theme)
        let background = hexString(theme.codeFill)

        var size = try await layout(
            source: trimmed,
            configuration: configuration,
            background: background,
            scale: 1,
            in: webView
        )

        // A very large diagram would make the snapshot expensive and the image
        // huge; re-lay it out smaller rather than clipping or downsampling it.
        let overflow = max(size.width, size.height) / maximumDiagramDimension
        if overflow > 1 {
            size = try await layout(
                source: trimmed,
                configuration: configuration,
                background: background,
                scale: 1 / overflow,
                in: webView
            )
        }

        webView.frame = CGRect(origin: offscreenOrigin, size: size)
        webView.setNeedsLayout()
        webView.layoutIfNeeded()
        // The resized viewport reaches the web content process asynchronously.
        try? await Task.sleep(for: .milliseconds(48))

        let snapshotConfiguration = WKSnapshotConfiguration()
        snapshotConfiguration.rect = CGRect(origin: .zero, size: size)
        snapshotConfiguration.snapshotWidth = NSNumber(value: Double(size.width))
        snapshotConfiguration.afterScreenUpdates = true

        let image = try await snapshot(webView, configuration: snapshotConfiguration)
        _ = try? await webView.callAsyncJavaScript(
            "window.marginMermaid.clear();",
            arguments: [:],
            in: nil,
            contentWorld: .page
        )
        return Diagram(image: image, size: size)
    }

    private func layout(
        source: String,
        configuration: [String: Any],
        background: String,
        scale: Double,
        in webView: WKWebView
    ) async throws -> CGSize {
        let result: Any?
        do {
            result = try await webView.callAsyncJavaScript(
                "return await window.marginMermaid.render(code, config, scale, background);",
                arguments: [
                    "code": source,
                    "config": configuration,
                    "scale": scale,
                    "background": background
                ],
                in: nil,
                contentWorld: .page
            )
        } catch {
            // A JS exception here is almost always mermaid rejecting the
            // diagram's syntax; surface its message to the reader.
            throw Failure.invalidDiagram(diagnostic(from: error))
        }

        guard let payload = result as? [String: Any],
              let width = payload["width"] as? Double,
              let height = payload["height"] as? Double,
              width > 0, height > 0 else {
            throw Failure.renderFailed
        }
        return CGSize(width: width, height: height)
    }

    private func snapshot(
        _ webView: WKWebView,
        configuration: WKSnapshotConfiguration
    ) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: configuration) { image, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: error ?? Failure.renderFailed)
                }
            }
        }
    }

    private func readyWebView() async throws -> WKWebView {
        if let webView {
            if webView.window == nil, let window = AppPresentationAnchor.keyWindow {
                window.insertSubview(webView, at: 0)
            }
            if webView.window != nil { return webView }
        }
        if let loadTask { return try await loadTask.value }

        let task = Task { @MainActor [weak self] () async throws -> WKWebView in
            guard let self else { throw Failure.unavailable }
            guard let hostURL = Bundle.main.url(
                forResource: "mermaid-host",
                withExtension: "html"
            ) else { throw Failure.unavailable }

            let webView = try self.makeWebView()
            do {
                let loader = MermaidNavigationLoader()
                webView.navigationDelegate = loader
                webView.loadFileURL(
                    hostURL,
                    allowingReadAccessTo: hostURL.deletingLastPathComponent()
                )
                try await loader.waitForLoad()
                webView.navigationDelegate = nil

                let ready = try? await webView.callAsyncJavaScript(
                    "return typeof window.marginMermaid === 'object' && typeof mermaid !== 'undefined';",
                    arguments: [:],
                    in: nil,
                    contentWorld: .page
                )
                guard (ready as? Bool) == true else { throw Failure.unavailable }
            } catch {
                webView.navigationDelegate = nil
                webView.removeFromSuperview()
                throw error
            }

            self.webView = webView
            return webView
        }
        loadTask = task

        do {
            let webView = try await task.value
            loadTask = nil
            return webView
        } catch {
            loadTask = nil
            self.webView = nil
            if let failure = error as? Failure { throw failure }
            throw Failure.unavailable
        }
    }

    // WebKit only renders — and therefore only snapshots — a web view that
    // lives in a window, so the renderer keeps one parked just past the key
    // window's leading edge: on screen enough for WebKit, never visible to the
    // reader. Hiding it by alpha instead would ruin every diagram, because
    // takeSnapshot bakes the view's own alpha into the image it hands back.
    private func makeWebView() throws -> WKWebView {
        guard let window = AppPresentationAnchor.keyWindow else {
            throw Failure.unavailable
        }

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.suppressesIncrementalRendering = true

        let webView = WKWebView(
            frame: CGRect(origin: offscreenOrigin, size: renderViewportSize),
            configuration: configuration
        )
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isUserInteractionEnabled = false
        webView.autoresizingMask = []
        window.insertSubview(webView, at: 0)
        return webView
    }

    private func diagnostic(from error: any Error) -> String {
        let userInfo = (error as NSError).userInfo
        let message = (userInfo["WKJavaScriptExceptionMessage"] as? String)
            ?? error.localizedDescription
        return message
            .replacingOccurrences(of: "Error: ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mermaidConfiguration(
        style: MermaidStyle,
        theme: MarkdownTheme
    ) -> [String: Any] {
        let isDark = style.colorScheme == .dark
        let themeVariables: [String: Any] = [
            "darkMode": isDark,
            "background": hexString(theme.codeFill),
            "fontFamily": fontFamily(for: style.readerTheme),
            "fontSize": "\(Int(style.fontSize.rounded()))px",
            "primaryColor": hexString(theme.quoteFill),
            "primaryTextColor": hexString(theme.textPrimary),
            "primaryBorderColor": hexString(theme.tableStrongRule),
            "secondaryColor": hexString(theme.frontMatterFill),
            "tertiaryColor": hexString(theme.canvas),
            "mainBkg": hexString(theme.quoteFill),
            "nodeBorder": hexString(theme.tableStrongRule),
            "clusterBkg": hexString(theme.canvas),
            "clusterBorder": hexString(theme.separator),
            "lineColor": hexString(theme.textSecondary),
            "textColor": hexString(theme.textPrimary),
            // Mermaid derives label colors from its own palette unless every
            // text variable is pinned, which drifts away from the theme.
            "nodeTextColor": hexString(theme.textPrimary),
            "labelTextColor": hexString(theme.textPrimary),
            "secondaryTextColor": hexString(theme.textPrimary),
            "tertiaryTextColor": hexString(theme.textPrimary),
            "titleColor": hexString(theme.textStrong),
            "edgeLabelBackground": hexString(theme.codeFill),
            "noteBkgColor": hexString(theme.frontMatterFill),
            "noteTextColor": hexString(theme.textPrimary),
            "noteBorderColor": hexString(theme.separator)
        ]

        return [
            "startOnLoad": false,
            // Diagrams come from documents the app did not write: keep mermaid's
            // sanitising renderer and its click handlers switched off.
            "securityLevel": "strict",
            "theme": "base",
            "darkMode": isDark,
            "fontFamily": fontFamily(for: style.readerTheme),
            "themeVariables": themeVariables,
            "flowchart": ["useMaxWidth": false, "htmlLabels": true],
            "sequence": ["useMaxWidth": false],
            "gantt": ["useMaxWidth": false],
            "class": ["useMaxWidth": false],
            "state": ["useMaxWidth": false],
            "pie": ["useMaxWidth": false],
            "journey": ["useMaxWidth": false],
            "er": ["useMaxWidth": false]
        ]
    }

    private func fontFamily(for readerTheme: ReaderTheme) -> String {
        switch readerTheme {
        case .claude:
            "ui-serif, Georgia, \"Songti SC\", serif"
        case .github:
            "-apple-system, \"Helvetica Neue\", \"PingFang SC\", sans-serif"
        }
    }

    private func hexString(_ color: Color) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#000000"
        }
        let channels = [red, green, blue].map { Int((min(max($0, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
    }
}

@MainActor
private final class MermaidNavigationLoader: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, any Error>?
    private var hasFinished = false

    func waitForLoad() async throws {
        if hasFinished { return }
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            // mermaid.js is a large script; never hang the reader on it.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(15))
                self.finish(with: MermaidRenderFailure.unavailable)
            }
        }
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
