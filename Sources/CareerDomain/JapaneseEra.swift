import Foundation

public enum JapaneseEra: String, Codable, CaseIterable, Equatable, Sendable {
    case showa
    case heisei
    case reiwa

    public var japaneseName: String {
        switch self {
        case .showa: "昭和"
        case .heisei: "平成"
        case .reiwa: "令和"
        }
    }
}

public struct JapaneseEraDate: Codable, Equatable, Sendable {
    public let era: JapaneseEra
    public let year: Int
    public let month: Int
    public let day: Int

    public init(era: JapaneseEra, year: Int, month: Int, day: Int) throws {
        guard year >= 1 else {
            throw EngineError.invalidInput("Era year must be positive")
        }
        let gregorianYear: Int
        switch era {
        case .showa: gregorianYear = 1925 + year
        case .heisei: gregorianYear = 1988 + year
        case .reiwa: gregorianYear = 2018 + year
        }
        let value = try PartialDate(year: gregorianYear, month: month, day: day)
        guard Self.range(for: era).contains(Self.ordinal(value)) else {
            throw EngineError.invalidInput("Date is outside the selected Japanese era")
        }
        self.era = era
        self.year = year
        self.month = month
        self.day = day
    }

    public init(gregorian: PartialDate) throws {
        guard let month = gregorian.month, let day = gregorian.day else {
            throw EngineError.invalidInput("Japanese era conversion requires a complete date")
        }
        let ordinal = Self.ordinal(gregorian)
        let era: JapaneseEra
        let firstYear: Int
        if Self.range(for: .reiwa).contains(ordinal) {
            era = .reiwa
            firstYear = 2019
        } else if Self.range(for: .heisei).contains(ordinal) {
            era = .heisei
            firstYear = 1989
        } else if Self.range(for: .showa).contains(ordinal) {
            era = .showa
            firstYear = 1926
        } else {
            throw EngineError.invalidInput("Date predates the supported Japanese eras")
        }
        self.era = era
        self.year = gregorian.year - firstYear + 1
        self.month = month
        self.day = day
    }

    public var gregorian: PartialDate {
        get throws {
            let yearOffset: Int
            switch era {
            case .showa: yearOffset = 1925
            case .heisei: yearOffset = 1988
            case .reiwa: yearOffset = 2018
            }
            return try PartialDate(year: yearOffset + year, month: month, day: day)
        }
    }

    public var displayString: String {
        let eraYear = year == 1 ? "元" : String(year)
        return "\(era.japaneseName)\(eraYear)年\(month)月\(day)日"
    }

    private static func ordinal(_ date: PartialDate) -> Int {
        date.year * 10_000 + (date.month ?? 1) * 100 + (date.day ?? 1)
    }

    private static func range(for era: JapaneseEra) -> ClosedRange<Int> {
        switch era {
        case .showa: 19_261_225...19_890_107
        case .heisei: 19_890_108...20_190_430
        case .reiwa: 20_190_501...22_001_231
        }
    }
}
