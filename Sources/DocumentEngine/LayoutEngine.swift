import CareerDomain
import Foundation

public struct MeasuredLine: Equatable, Sendable {
    public let text: String
    public let height: Double

    public init(text: String, height: Double) {
        self.text = text
        self.height = height
    }
}

public protocol TextMeasurer: Sendable {
    func measure(text: String, style: TextStyle, width: Double) throws -> [MeasuredLine]
}

public struct LayoutRect: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct TextPlacement: Codable, Equatable, Sendable {
    public let fieldID: String
    public let lineIndex: Int
    public let text: String
    public let frame: LayoutRect
    public let style: TextStyle

    public init(fieldID: String, lineIndex: Int, text: String, frame: LayoutRect, style: TextStyle) {
        self.fieldID = fieldID
        self.lineIndex = lineIndex
        self.text = text
        self.frame = frame
        self.style = style
    }
}

public struct PageLayout: Codable, Equatable, Sendable {
    public let index: Int
    public var textPlacements: [TextPlacement]

    public init(index: Int, textPlacements: [TextPlacement] = []) {
        self.index = index
        self.textPlacements = textPlacements
    }
}

public struct LayoutIssue: Codable, Equatable, Sendable {
    public enum Code: String, Codable, Equatable, Sendable {
        case missingRequiredField
        case emptyMeasurement
        case unsplittableField
        case unplacedField
    }

    public let code: Code
    public let fieldID: String
    public let message: String

    public init(code: Code, fieldID: String, message: String) {
        self.code = code
        self.fieldID = fieldID
        self.message = message
    }
}

public struct LayoutPlan: Codable, Equatable, Sendable {
    public let snapshotHash: UInt64
    public let pageSpec: PageSpec
    public let pages: [PageLayout]
    public let issues: [LayoutIssue]

    public init(snapshotHash: UInt64, pageSpec: PageSpec, pages: [PageLayout], issues: [LayoutIssue]) {
        self.snapshotHash = snapshotHash
        self.pageSpec = pageSpec
        self.pages = pages
        self.issues = issues
    }

    public var placedFieldIDs: Set<String> {
        Set(pages.flatMap(\.textPlacements).map(\.fieldID))
    }

    public var canRender: Bool { issues.isEmpty }
}

public struct LayoutEngine: Sendable {
    private let measurer: any TextMeasurer

    public init(measurer: any TextMeasurer) {
        self.measurer = measurer
    }

    public func layout(_ snapshot: DocumentSnapshot) throws -> LayoutPlan {
        var pages = [PageLayout(index: 0)]
        var pageIndex = 0
        var y = snapshot.page.topMargin
        var issues: [LayoutIssue] = []

        for field in snapshot.fields {
            let normalized = field.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if field.isRequired && normalized.isEmpty {
                issues.append(.init(code: .missingRequiredField, fieldID: field.id, message: "Required field is empty"))
                continue
            }
            if normalized.isEmpty { continue }

            let lines = try measurer.measure(text: normalized, style: field.style, width: snapshot.page.contentWidth)
            guard !lines.isEmpty else {
                issues.append(.init(code: .emptyMeasurement, fieldID: field.id, message: "Text measurement produced no lines"))
                continue
            }

            let totalHeight = field.style.spacingBefore
                + lines.reduce(0) { $0 + $1.height }
                + field.style.spacingAfter
            if field.keepTogether && totalHeight > snapshot.page.contentHeight {
                issues.append(.init(code: .unsplittableField, fieldID: field.id, message: "Field cannot fit on one page"))
                continue
            }

            if field.keepTogether && y + totalHeight > snapshot.page.height - snapshot.page.bottomMargin {
                pageIndex += 1
                pages.append(PageLayout(index: pageIndex))
                y = snapshot.page.topMargin
            }

            y += field.style.spacingBefore
            for (lineIndex, line) in lines.enumerated() {
                if y + line.height > snapshot.page.height - snapshot.page.bottomMargin {
                    pageIndex += 1
                    pages.append(PageLayout(index: pageIndex))
                    y = snapshot.page.topMargin
                }
                let frame = LayoutRect(
                    x: snapshot.page.leftMargin,
                    y: y,
                    width: snapshot.page.contentWidth,
                    height: line.height
                )
                pages[pageIndex].textPlacements.append(.init(
                    fieldID: field.id,
                    lineIndex: lineIndex,
                    text: line.text,
                    frame: frame,
                    style: field.style
                ))
                y += line.height
            }
            y += field.style.spacingAfter
        }

        let expected = Set(snapshot.fields.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map(\.id))
        let placed = Set(pages.flatMap(\.textPlacements).map(\.fieldID))
        for missing in expected.subtracting(placed) where !issues.contains(where: { $0.fieldID == missing }) {
            issues.append(.init(code: .unplacedField, fieldID: missing, message: "Field was not placed in the document"))
        }

        return LayoutPlan(
            snapshotHash: snapshot.stableContentHash,
            pageSpec: snapshot.page,
            pages: pages,
            issues: issues
        )
    }
}
