#if CATWALK_ENABLED
//
//  CWDERTime.swift
//  CatWalk
//

import Foundation

/// `UTCTime` (`YYMMDDHHMMSSZ`) and `GeneralizedTime` (`YYYYMMDDHHMMSSZ`), the forms RFC 5280 allows.
enum CWDERTime {

    private static let utcTimeLength = 13
    private static let generalizedTimeLength = 15
    /// RFC 5280: UTCTime years 50–99 are 19xx, 00–49 are 20xx.
    private static let utcCenturyPivot = 50

    static func date(from element: CWDERElement) throws(CWDERError) -> Date {
        guard let text = String(bytes: element.content, encoding: .ascii), text.hasSuffix("Z") else {
            throw .invalidValue
        }
        let digits = Array(text.dropLast())
        guard digits.allSatisfy(\.isASCIIDigit) else { throw .invalidValue }

        let year: Int
        let rest: ArraySlice<Character>
        switch (element.tag, text.count) {
        case (CWDERElement.utcTime, utcTimeLength):
            let short = number(digits[0..<2])
            year = short < utcCenturyPivot ? 2000 + short : 1900 + short
            rest = digits[2...]
        case (CWDERElement.generalizedTime, generalizedTimeLength):
            year = number(digits[0..<4])
            rest = digits[4...]
        default:
            throw .invalidValue
        }

        let start = rest.startIndex
        let components = DateComponents(
            calendar: utcCalendar,
            timeZone: TimeZone(identifier: "UTC"),
            year: year,
            month: number(rest[start..<(start + 2)]),
            day: number(rest[(start + 2)..<(start + 4)]),
            hour: number(rest[(start + 4)..<(start + 6)]),
            minute: number(rest[(start + 6)..<(start + 8)]),
            second: number(rest[(start + 8)..<(start + 10)])
        )
        guard components.isValidDate, let date = components.date else { throw .invalidValue }
        return date
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private static func number(_ digits: ArraySlice<Character>) -> Int {
        digits.reduce(0) { $0 * 10 + ($1.wholeNumberValue ?? 0) }
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
#endif
