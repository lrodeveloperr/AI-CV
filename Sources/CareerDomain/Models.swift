import Foundation

public struct PartialDate: Codable, Hashable, Sendable, Comparable {
    public let year: Int
    public let month: Int?
    public let day: Int?

    public init(year: Int, month: Int? = nil, day: Int? = nil) throws {
        guard (1868...2200).contains(year) else {
            throw EngineError.invalidInput("Year is outside the supported range")
        }
        if let month, !(1...12).contains(month) {
            throw EngineError.invalidInput("Month must be between 1 and 12")
        }
        if day != nil && month == nil {
            throw EngineError.invalidInput("A day requires a month")
        }
        if let month, let day {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            guard calendar.date(from: DateComponents(year: year, month: month, day: day)) != nil else {
                throw EngineError.invalidInput("The date is not valid")
            }
        }
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: PartialDate, rhs: PartialDate) -> Bool {
        (lhs.year, lhs.month ?? 1, lhs.day ?? 1) < (rhs.year, rhs.month ?? 1, rhs.day ?? 1)
    }
}

public enum DateDisplayStyle: String, Codable, Hashable, Sendable {
    case gregorian
    case japaneseEra
}

public struct ContactDetails: Codable, Equatable, Sendable {
    public var fullName: String
    public var phoneticName: String?
    public var email: String?
    public var phone: String?
    public var postalCode: String?
    public var address: String?

    public init(
        fullName: String,
        phoneticName: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        postalCode: String? = nil,
        address: String? = nil
    ) {
        self.fullName = fullName
        self.phoneticName = phoneticName
        self.email = email
        self.phone = phone
        self.postalCode = postalCode
        self.address = address
    }
}

public struct Education: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var school: String
    public var course: String?
    public var start: PartialDate?
    public var end: PartialDate?
    public var isConfirmed: Bool

    public init(
        id: UUID = UUID(),
        school: String,
        course: String? = nil,
        start: PartialDate? = nil,
        end: PartialDate? = nil,
        isConfirmed: Bool = true
    ) {
        self.id = id
        self.school = school
        self.course = course
        self.start = start
        self.end = end
        self.isConfirmed = isConfirmed
    }
}

public struct Employment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var employer: String
    public var title: String?
    public var start: PartialDate?
    public var end: PartialDate?
    public var isCurrent: Bool
    public var responsibilities: [String]
    public var isConfirmed: Bool

    public init(
        id: UUID = UUID(),
        employer: String,
        title: String? = nil,
        start: PartialDate? = nil,
        end: PartialDate? = nil,
        isCurrent: Bool = false,
        responsibilities: [String] = [],
        isConfirmed: Bool = true
    ) {
        self.id = id
        self.employer = employer
        self.title = title
        self.start = start
        self.end = end
        self.isCurrent = isCurrent
        self.responsibilities = responsibilities
        self.isConfirmed = isConfirmed
    }
}

public struct Qualification: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var issuer: String?
    public var awarded: PartialDate?
    public var isConfirmed: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        issuer: String? = nil,
        awarded: PartialDate? = nil,
        isConfirmed: Bool = true
    ) {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.awarded = awarded
        self.isConfirmed = isConfirmed
    }
}

public struct Achievement: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var isConfirmed: Bool

    public init(id: UUID = UUID(), text: String, isConfirmed: Bool = true) {
        self.id = id
        self.text = text
        self.isConfirmed = isConfirmed
    }
}

public struct CareerProfile: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var contact: ContactDetails
    public var education: [Education]
    public var employment: [Employment]
    public var qualifications: [Qualification]
    public var achievements: [Achievement]

    public init(
        id: UUID = UUID(),
        contact: ContactDetails,
        education: [Education] = [],
        employment: [Employment] = [],
        qualifications: [Qualification] = [],
        achievements: [Achievement] = []
    ) {
        self.id = id
        self.contact = contact
        self.education = education
        self.employment = employment
        self.qualifications = qualifications
        self.achievements = achievements
    }

    public var confirmedFactIDs: Set<UUID> {
        Set(education.filter(\.isConfirmed).map(\.id))
            .union(employment.filter(\.isConfirmed).map(\.id))
            .union(qualifications.filter(\.isConfirmed).map(\.id))
            .union(achievements.filter(\.isConfirmed).map(\.id))
    }
}

public enum NarrativeField: Codable, Equatable, Hashable, Sendable {
    case selfPromotion
    case motivation
    case careerSummary
    case employmentSummary(UUID)
}

public struct Narrative: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let field: NarrativeField
    public var text: String
    public var citedFactIDs: Set<UUID>
    public var acceptedAt: Date

    public init(
        id: UUID = UUID(),
        field: NarrativeField,
        text: String,
        citedFactIDs: Set<UUID>,
        acceptedAt: Date
    ) {
        self.id = id
        self.field = field
        self.text = text
        self.citedFactIDs = citedFactIDs
        self.acceptedAt = acceptedAt
    }
}

public enum DocumentKind: String, Codable, CaseIterable, Hashable, Sendable {
    case resume
    case workHistory
    case coverLetter
}

public struct DocumentRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var kind: DocumentKind
    public var title: String
    public var templateID: String
    public var dateStyle: DateDisplayStyle
    public var narratives: [Narrative]
    public var applicationID: UUID?
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        kind: DocumentKind,
        title: String,
        templateID: String = "standard-ja-v1",
        dateStyle: DateDisplayStyle = .japaneseEra,
        narratives: [Narrative] = [],
        applicationID: UUID? = nil,
        createdAt: Date,
        modifiedAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.templateID = templateID
        self.dateStyle = dateStyle
        self.narratives = narratives
        self.applicationID = applicationID
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct DocumentVersion: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let documentID: UUID
    public let profile: CareerProfile
    public let document: DocumentRecord
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        documentID: UUID,
        profile: CareerProfile,
        document: DocumentRecord,
        createdAt: Date
    ) {
        self.id = id
        self.documentID = documentID
        self.profile = profile
        self.document = document
        self.createdAt = createdAt
    }
}

public enum ApplicationStage: String, Codable, CaseIterable, Hashable, Sendable {
    case preparing
    case submitted
    case interviewing
    case offered
    case rejected
    case withdrawn
}

public struct JobApplication: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var company: String
    public var role: String
    public var vacancyText: String?
    public var stage: ApplicationStage
    public var deadline: Date?
    public var documentIDs: Set<UUID>
    public var documentVersionIDs: Set<UUID>
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        company: String,
        role: String,
        vacancyText: String? = nil,
        stage: ApplicationStage = .preparing,
        deadline: Date? = nil,
        documentIDs: Set<UUID> = [],
        documentVersionIDs: Set<UUID> = [],
        modifiedAt: Date
    ) {
        self.id = id
        self.company = company
        self.role = role
        self.vacancyText = vacancyText
        self.stage = stage
        self.deadline = deadline
        self.documentIDs = documentIDs
        self.documentVersionIDs = documentVersionIDs
        self.modifiedAt = modifiedAt
    }
}

public struct Workspace: Codable, Equatable, Sendable {
    public var profile: CareerProfile
    public var documents: [DocumentRecord]
    public var documentVersions: [DocumentVersion]
    public var applications: [JobApplication]
    public var usage: UsageLedger
    public var processedOperationIDs: Set<UUID>
    public var revision: Int

    public init(
        profile: CareerProfile,
        documents: [DocumentRecord] = [],
        documentVersions: [DocumentVersion] = [],
        applications: [JobApplication] = [],
        usage: UsageLedger = UsageLedger(),
        processedOperationIDs: Set<UUID> = [],
        revision: Int = 0
    ) {
        self.profile = profile
        self.documents = documents
        self.documentVersions = documentVersions
        self.applications = applications
        self.usage = usage
        self.processedOperationIDs = processedOperationIDs
        self.revision = revision
    }
}
