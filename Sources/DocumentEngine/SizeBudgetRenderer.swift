import CareerDomain
import Foundation

/// A renderer that can regenerate the document with a lower-quality portrait.
/// Text always stays vector content; only the portrait is ever degraded.
public protocol PortraitQualityRendering: Sendable {
    func render(_ plan: LayoutPlan, portraitQuality: Double) async throws -> RenderedDocument
}

extension CoreGraphicsPDFRenderer: PortraitQualityRendering {
    public func render(_ plan: LayoutPlan, portraitQuality: Double) async throws -> RenderedDocument {
        try renderPDF(plan, portraitQuality: portraitQuality)
    }
}

public struct SizedRender: Equatable, Sendable {
    public let document: RenderedDocument
    public let portraitQuality: Double
    public let attempts: Int

    public init(document: RenderedDocument, portraitQuality: Double, attempts: Int) {
        self.document = document
        self.portraitQuality = portraitQuality
        self.attempts = attempts
    }
}

/// Implements the file-size policy: render once at normal quality, measure the
/// exact bytes, recompress only the portrait down a fixed ladder to the
/// documented minimum, and block export if the ceiling is still exceeded.
public struct SizeBudgetRenderer: Sendable {
    public static let normalQuality = 0.9
    public static let minimumQuality = 0.45
    public static let qualityLadder: [Double] = [0.9, 0.75, 0.6, 0.45]

    private let renderer: any PortraitQualityRendering

    public init(renderer: any PortraitQualityRendering) {
        self.renderer = renderer
    }

    public func render(snapshot: DocumentSnapshot, plan: LayoutPlan) async throws -> SizedRender {
        guard plan.canRender else {
            throw EngineError.validation(plan.issues.map { issue in
                ValidationIssue(
                    code: "layout.\(issue.code.rawValue)",
                    message: issue.message,
                    path: "document.fields.\(issue.fieldID)",
                    severity: .blocking
                )
            })
        }

        // Without a portrait there is nothing that may be degraded.
        let ladder = snapshot.portraitBytes > 0 ? Self.qualityLadder : [Self.normalQuality]
        var attempts = 0
        var lastSize = 0

        for quality in ladder {
            if Task.isCancelled { throw EngineError.canceled }
            attempts += 1
            let document = try await renderer.render(plan, portraitQuality: quality)
            lastSize = document.data.count
            if lastSize <= snapshot.maximumPDFBytes {
                return SizedRender(document: document, portraitQuality: quality, attempts: attempts)
            }
        }

        throw EngineError.validation([ValidationIssue(
            code: "pdf.size.exceeded",
            message: "Rendered PDF is \(lastSize) bytes after \(attempts) attempt(s), above the \(snapshot.maximumPDFBytes) byte limit; choose a larger size limit or a smaller portrait",
            path: "document.render",
            severity: .blocking
        )])
    }
}
