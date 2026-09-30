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

public struct PortraitPlacement: Codable, Equatable, Sendable {
    public let frame: LayoutRect
    public let image: PortraitImage

    public init(frame: LayoutRect, image: PortraitImage) {
        self.frame = frame
        self.image = image
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
        case portraitTooSmall
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
    /// Always drawn on page 0.
    public let portrait: PortraitPlacement?

    public init(
        snapshotHash: UInt64,
        pageSpec: PageSpec,
        pages: [PageLayout],
        issues: [LayoutIssue],
        portrait: PortraitPlacement? = nil
    ) {
        self.snapshotHash = snapshotHash
        self.pageSpec = pageSpec
        self.pages = pages
        self.issues = issues
        self.portrait = portrait
    }

    public var placedFieldIDs: Set<String> {
        Set(pages.flatMap(\.textPlacements).map(\.fieldID))
    }

    public var canRender: Bool { issues.isEmpty }
}

public struct LayoutEngine: Sendable {
    /// Standard 30 mm x 40 mm résumé photo, in points.
    public static let portraitWidth = 85.04
    public static let portraitHeight = 113.39
    public static let portraitGap = 12.0
    public static let minimumPortraitPixelWidth = 240
    public static let minimumPortraitPixelHeight = 320

    private let measurer: any TextMeasurer

    public init(measurer: any TextMeasurer) {
        self.measurer = measurer
    }

    public func layout(_ snapshot: DocumentSnapshot) throws -> LayoutPlan {
        var pages = [PageLayout(index: 0)]
        var pageIndex = 0
        var y = snapshot.page.topMargin
        var issues: [LayoutIssue] = []

        var portraitPlacement: PortraitPlacement?
        if let image = snapshot.portrait {
            if image.pixelWidth < Self.minimumPortraitPixelWidth
                || image.pixelHeight < Self.minimumPortraitPixelHeight {
                issues.append(.init(
                    code: .portraitTooSmall,
                    fieldID: "portrait",
                    message: "Portrait resolution is below the \(Self.minimumPortraitPixelWidth)x\(Self.minimumPortraitPixelHeight) pixel minimum"
                ))
            }
            portraitPlacement = PortraitPlacement(
                frame: LayoutRect(
                    x: snapshot.page.width - snapshot.page.rightMargin - Self.portraitWidth,
                    y: snapshot.page.topMargin,
                    width: Self.portraitWidth,
                    height: Self.portraitHeight
                ),
                image: image
            )
        }
        let portraitBottom = portraitPlacement.map { $0.frame.y + $0.frame.height + Self.portraitGap }
        let narrowWidth = snapshot.page.contentWidth - Self.portraitWidth - Self.portraitGap

        for field in snapshot.fields {
            let normalized = field.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if field.isRequired && normalized.isEmpty {
                issues.append(.init(code: .missingRequiredField, fieldID: field.id, message: "Required field is empty"))
                continue
            }
            if normalized.isEmpty { continue }

            // Text that starts beside the portrait wraps in the narrower column.
            let besidePortrait = pageIndex == 0 && (portraitBottom.map { y < $0 } ?? false)
            let width = besidePortrait ? narrowWidth : snapshot.page.contentWidth
            let lines = try measurer.measure(text: normalized, style: field.style, width: width)
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
                    width: width,
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
            issues: issues,
            portrait: portraitPlacement
        )
    }
}
