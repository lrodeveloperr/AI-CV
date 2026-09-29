import Foundation

public enum CareerValidator {
    public static func validate(_ profile: CareerProfile) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if profile.contact.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(
                code: "profile.name.required",
                message: "A full name is required",
                path: "profile.contact.fullName",
                severity: .blocking
            ))
        }

        var allIDs: [UUID] = []
        allIDs.append(contentsOf: profile.education.map(\.id))
        allIDs.append(contentsOf: profile.employment.map(\.id))
        allIDs.append(contentsOf: profile.qualifications.map(\.id))
        allIDs.append(contentsOf: profile.achievements.map(\.id))
        if Set(allIDs).count != allIDs.count {
            issues.append(.init(
                code: "profile.fact.duplicate-id",
                message: "Career facts must have unique identifiers",
                path: "profile",
                severity: .blocking
            ))
        }

        for item in profile.education {
            if item.school.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(code: "education.school.required", message: "School is required", path: "education.\(item.id).school", severity: .blocking))
            }
            if let start = item.start, let end = item.end, end < start {
                issues.append(.init(code: "education.date.order", message: "Education end date precedes its start date", path: "education.\(item.id)", severity: .blocking))
            }
        }

        for item in profile.employment {
            if item.employer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(code: "employment.employer.required", message: "Employer is required", path: "employment.\(item.id).employer", severity: .blocking))
            }
            if let start = item.start, let end = item.end, end < start {
                issues.append(.init(code: "employment.date.order", message: "Employment end date precedes its start date", path: "employment.\(item.id)", severity: .blocking))
            }
            if item.isCurrent && item.end != nil {
                issues.append(.init(code: "employment.current.has-end", message: "A current role cannot have an end date", path: "employment.\(item.id).end", severity: .blocking))
            }
        }

        for item in profile.qualifications where item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(code: "qualification.name.required", message: "Qualification name is required", path: "qualifications.\(item.id).name", severity: .blocking))
        }

        return issues
    }

    public static func validate(_ document: DocumentRecord, against profile: CareerProfile) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if document.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(code: "document.title.required", message: "Document title is required", path: "document.title", severity: .blocking))
        }
        let permitted = profile.confirmedFactIDs
        for narrative in document.narratives {
            let unsupported = narrative.citedFactIDs.subtracting(permitted)
            if !unsupported.isEmpty {
                issues.append(.init(
                    code: "narrative.unconfirmed-fact",
                    message: "Narrative cites an unconfirmed or missing career fact",
                    path: "document.narratives.\(narrative.id)",
                    severity: .blocking
                ))
            }
        }
        return issues
    }
}

