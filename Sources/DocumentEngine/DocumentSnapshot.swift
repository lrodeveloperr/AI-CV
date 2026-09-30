import CareerDomain
import Foundation

public enum DocumentSection: String, Codable, Equatable, Sendable {
    case identity
    case contact
    case education
    case employment
    case qualifications
    case narrative
    case application
}

public struct TextStyle: Codable, Equatable, Sendable {
    public let fontName: String
    public let fontSize: Double
    public let lineHeight: Double
    public let spacingBefore: Double
    public let spacingAfter: Double

    public init(
        fontName: String = "system",
        fontSize: Double = 10,
        lineHeight: Double = 14,
        spacingBefore: Double = 0,
        spacingAfter: Double = 4
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.spacingBefore = spacingBefore
        self.spacingAfter = spacingAfter
    }
}

public struct DocumentField: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let section: DocumentSection
    public let text: String
    public let style: TextStyle
    public let isRequired: Bool
    public let keepTogether: Bool

    public init(
        id: String,
        section: DocumentSection,
        text: String,
        style: TextStyle = TextStyle(),
        isRequired: Bool = false,
        keepTogether: Bool = false
    ) {
        self.id = id
        self.section = section
        self.text = text
        self.style = style
        self.isRequired = isRequired
        self.keepTogether = keepTogether
    }
}

public struct PageSpec: Codable, Equatable, Sendable {
    public let width: Double
    public let height: Double
    public let topMargin: Double
    public let rightMargin: Double
    public let bottomMargin: Double
    public let leftMargin: Double

    public init(
        width: Double,
        height: Double,
        topMargin: Double,
        rightMargin: Double,
        bottomMargin: Double,
        leftMargin: Double
    ) {
        self.width = width
        self.height = height
        self.topMargin = topMargin
        self.rightMargin = rightMargin
        self.bottomMargin = bottomMargin
        self.leftMargin = leftMargin
    }

    public static let a4 = PageSpec(
        width: 595.28,
        height: 841.89,
        topMargin: 42,
        rightMargin: 42,
        bottomMargin: 42,
        leftMargin: 42
    )

    public var contentWidth: Double { width - leftMargin - rightMargin }
    public var contentHeight: Double { height - topMargin - bottomMargin }
}

public struct PortraitImage: Codable, Equatable, Sendable {
    public let data: Data
    public let pixelWidth: Int
    public let pixelHeight: Int

    public init(data: Data, pixelWidth: Int, pixelHeight: Int) {
        self.data = data
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

public struct DocumentSnapshot: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let documentID: UUID
    public let kind: DocumentKind
    public let templateID: String
    public let page: PageSpec
    public let fields: [DocumentField]
    public let maximumPDFBytes: Int
    public let portraitBytes: Int
    public let portrait: PortraitImage?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        documentID: UUID,
        kind: DocumentKind,
        templateID: String,
        page: PageSpec = .a4,
        fields: [DocumentField],
        maximumPDFBytes: Int,
        portraitBytes: Int = 0,
        portrait: PortraitImage? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.documentID = documentID
        self.kind = kind
        self.templateID = templateID
        self.page = page
        self.fields = fields
        self.maximumPDFBytes = maximumPDFBytes
        self.portraitBytes = portrait?.data.count ?? portraitBytes
        self.portrait = portrait
        self.createdAt = createdAt
    }

    public var stableContentHash: UInt64 {
        var hasher = StableHasher()
        hasher.combine(documentID.uuidString)
        hasher.combine(kind.rawValue)
        hasher.combine(templateID)
        hasher.combine(String(maximumPDFBytes))
        if let portrait {
            hasher.combine(data: portrait.data)
            hasher.combine("\(portrait.pixelWidth)x\(portrait.pixelHeight)")
        }
        for field in fields {
            hasher.combine(field.id)
            hasher.combine(field.section.rawValue)
            hasher.combine(field.text)
            hasher.combine(String(field.style.fontSize))
            hasher.combine(String(field.style.lineHeight))
        }
        return hasher.value
    }
}

struct StableHasher {
    private(set) var value: UInt64 = 14_695_981_039_346_656_037

    mutating func combine(data: Data) {
        for byte in data {
            value ^= UInt64(byte)
            value &*= 1_099_511_628_211
        }
        value ^= 0xFE
        value &*= 1_099_511_628_211
    }

    mutating func combine(_ string: String) {
        for byte in string.utf8 {
            value ^= UInt64(byte)
            value &*= 1_099_511_628_211
        }
        value ^= 0xFF
        value &*= 1_099_511_628_211
    }
}
