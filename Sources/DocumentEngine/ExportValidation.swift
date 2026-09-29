import CareerDomain
import Foundation

public struct RenderedDocument: Equatable, Sendable {
    public let data: Data
    public let snapshotHash: UInt64
    public let pageCount: Int

    public init(data: Data, snapshotHash: UInt64, pageCount: Int) {
        self.data = data
        self.snapshotHash = snapshotHash
        self.pageCount = pageCount
    }
}

public protocol DocumentRendering: Sendable {
    func render(_ plan: LayoutPlan) async throws -> RenderedDocument
}

public struct ExportValidation: Equatable, Sendable {
    public let isValid: Bool
    public let issues: [ValidationIssue]

    public init(isValid: Bool, issues: [ValidationIssue]) {
        self.isValid = isValid
        self.issues = issues
    }
}

public enum ExportValidator {
    public static func validate(
        artifact: RenderedDocument,
        snapshot: DocumentSnapshot,
        plan: LayoutPlan
    ) -> ExportValidation {
        var issues: [ValidationIssue] = []
        if !plan.issues.isEmpty {
            issues.append(.init(
                code: "pdf.layout.invalid",
                message: "Document layout has unresolved issues",
                path: "document.layout",
                severity: .blocking
            ))
        }
        if artifact.snapshotHash != snapshot.stableContentHash || artifact.snapshotHash != plan.snapshotHash {
            issues.append(.init(
                code: "pdf.snapshot.mismatch",
                message: "Rendered PDF does not match the current document snapshot",
                path: "document.render",
                severity: .blocking
            ))
        }
        if artifact.pageCount != plan.pages.count {
            issues.append(.init(
                code: "pdf.page-count.mismatch",
                message: "Rendered PDF page count differs from the layout plan",
                path: "document.render",
                severity: .blocking
            ))
        }
        if artifact.data.count > snapshot.maximumPDFBytes {
            issues.append(.init(
                code: "pdf.size.exceeded",
                message: "Rendered PDF exceeds the selected file-size limit",
                path: "document.render",
                severity: .blocking
            ))
        }
        if artifact.data.isEmpty {
            issues.append(.init(
                code: "pdf.empty",
                message: "Rendered PDF is empty",
                path: "document.render",
                severity: .blocking
            ))
        }
        return ExportValidation(isValid: issues.isEmpty, issues: issues)
    }
}

