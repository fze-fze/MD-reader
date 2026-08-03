import Foundation
import UIKit

@MainActor
enum DocumentPrinter {
    // Diagrams have to be rendered before the markup is built, so presenting
    // the print sheet waits on them the way PDF export does.
    static func present(
        text: String,
        title: String,
        theme: ReaderTheme,
        baseURL: URL? = nil
    ) async {
        let markup = await MarkdownPrintRenderer.preparedHTML(
            source: text,
            title: title,
            theme: theme,
            baseURL: baseURL
        )

        let controller = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = title
        printInfo.outputType = .general
        controller.printInfo = printInfo
        controller.showsNumberOfCopies = true

        let formatter = UIMarkupTextPrintFormatter(markupText: markup)
        controller.printFormatter = formatter
        controller.present(animated: true)
    }
}
