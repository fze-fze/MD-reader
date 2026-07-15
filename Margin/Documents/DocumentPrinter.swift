import Foundation
import UIKit

@MainActor
enum DocumentPrinter {
    static func present(text: String, title: String, baseURL: URL? = nil) {
        let controller = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = title
        printInfo.outputType = .general
        controller.printInfo = printInfo
        controller.showsNumberOfCopies = true

        let formatter = UIMarkupTextPrintFormatter(
            markupText: MarkdownPrintRenderer.html(
                source: text,
                title: title,
                baseURL: baseURL
            )
        )
        controller.printFormatter = formatter
        controller.present(animated: true)
    }
}
