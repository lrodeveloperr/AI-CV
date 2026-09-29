import CareerDomain
import CoreGraphics
import CoreText
import Foundation

public struct CoreTextMeasurer: TextMeasurer {
    public init() {}

    public func measure(text: String, style: TextStyle, width: Double) throws -> [MeasuredLine] {
        guard width > 0 else {
            throw EngineError.invalidInput("Text width must be positive")
        }
        let attributed = NSAttributedString(
            string: text,
            attributes: Self.attributes(for: style)
        )
        let typesetter = CTTypesetterCreateWithAttributedString(attributed as CFAttributedString)
        let source = text as NSString
        var offset = 0
        var lines: [MeasuredLine] = []

        while offset < source.length {
            let count = CTTypesetterSuggestLineBreak(typesetter, offset, CGFloat(width))
            guard count > 0 else {
                throw EngineError.internalFailure("Core Text could not advance line layout")
            }
            let range = NSRange(location: offset, length: count)
            let lineText = source.substring(with: range)
                .trimmingCharacters(in: .newlines)
            lines.append(MeasuredLine(text: lineText, height: style.lineHeight))
            offset += count
        }
        return lines
    }

    static func attributes(for style: TextStyle) -> [NSAttributedString.Key: Any] {
        let font: CTFont
        if style.fontName == "system" {
            font = CTFontCreateUIFontForLanguage(.system, CGFloat(style.fontSize), "ja" as CFString)
                ?? CTFontCreateWithName("HiraginoSans-W3" as CFString, CGFloat(style.fontSize), nil)
        } else {
            font = CTFontCreateWithName(style.fontName as CFString, CGFloat(style.fontSize), nil)
        }
        return [NSAttributedString.Key(kCTFontAttributeName as String): font]
    }
}

public struct CoreGraphicsPDFRenderer: DocumentRendering {
    public init() {}

    public func render(_ plan: LayoutPlan) async throws -> RenderedDocument {
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

        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData) else {
            throw EngineError.internalFailure("Unable to create PDF data consumer")
        }
        var mediaBox = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(plan.pageSpec.width),
            height: CGFloat(plan.pageSpec.height)
        )
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw EngineError.internalFailure("Unable to create PDF context")
        }

        for page in plan.pages {
            context.beginPDFPage(nil)
            context.setFillColor(gray: 0, alpha: 1)
            context.textMatrix = .identity
            for placement in page.textPlacements {
                let attributed = NSAttributedString(
                    string: placement.text,
                    attributes: CoreTextMeasurer.attributes(for: placement.style)
                )
                let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
                let baseline = plan.pageSpec.height - placement.frame.y - placement.frame.height
                context.textPosition = CGPoint(x: CGFloat(placement.frame.x), y: CGFloat(baseline))
                CTLineDraw(line, context)
            }
            context.endPDFPage()
        }
        context.closePDF()

        let data = output as Data
        guard !data.isEmpty else {
            throw EngineError.internalFailure("PDF renderer produced no data")
        }
        return RenderedDocument(
            data: data,
            snapshotHash: plan.snapshotHash,
            pageCount: plan.pages.count
        )
    }
}
