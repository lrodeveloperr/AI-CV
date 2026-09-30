#if canImport(PDFKit) && canImport(SwiftUI)
import DocumentEngine
import PDFKit
import SwiftUI

/// Displays the exact validated PDF bytes. There is no separate visual
/// approximation of the document.
#if canImport(UIKit)
public struct PDFPreviewView: UIViewRepresentable {
    private let artifact: ExportArtifact

    public init(artifact: ExportArtifact) {
        self.artifact = artifact
    }

    public func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(data: artifact.data)
        return view
    }

    public func updateUIView(_ view: PDFView, context: Context) {
        view.document = PDFDocument(data: artifact.data)
    }
}
#elseif canImport(AppKit)
public struct PDFPreviewView: NSViewRepresentable {
    private let artifact: ExportArtifact

    public init(artifact: ExportArtifact) {
        self.artifact = artifact
    }

    public func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(data: artifact.data)
        return view
    }

    public func updateNSView(_ view: PDFView, context: Context) {
        view.document = PDFDocument(data: artifact.data)
    }
}
#endif
#endif
