#if canImport(UIKit)
import SwiftUI
import UIKit

/// Native share sheet for an exported PDF file. The completion reports whether
/// the user actually completed a handoff, which is what consumes the free export.
public struct ShareSheet: UIViewControllerRepresentable {
    private let fileURL: URL
    private let onFinish: (ExportHandoffOutcome) -> Void

    public init(fileURL: URL, onFinish: @escaping (ExportHandoffOutcome) -> Void) {
        self.fileURL = fileURL
        self.onFinish = onFinish
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, error in
            if error != nil {
                onFinish(.failed)
            } else {
                onFinish(completed ? .completed : .canceled)
            }
        }
        return controller
    }

    public func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// AirPrint handoff of the same PDF bytes.
@MainActor
public enum PDFPrinter {
    public static func present(
        _ artifact: ExportArtifact,
        jobName: String,
        onFinish: @escaping (ExportHandoffOutcome) -> Void
    ) {
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = jobName

        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printingItem = artifact.data
        controller.present(animated: true) { _, completed, error in
            if error != nil {
                onFinish(.failed)
            } else {
                onFinish(completed ? .completed : .canceled)
            }
        }
    }
}
#endif
