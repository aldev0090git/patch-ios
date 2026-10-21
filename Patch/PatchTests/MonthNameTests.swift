import Foundation
import Testing
@testable import Patch

/// A month name on its own is a heading, and languages disagree about how a
/// heading is capitalised.
@Suite("Month names")
struct MonthNameTests {
    private func october(_ identifier: String) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let locale = Locale(identifier: identifier)
        calendar.locale = locale
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 21)) ?? .now
        return MonthName.standalone(date, calendar: calendar, locale: locale)
    }

    @Test("Russian capitalises a month standing on its own")
    func russianIsCapitalised() throws {
        let name = october("ru_RU")
        let first = try #require(name.first)
        #expect(first.isUppercase, "Got \(name) — a heading, so it wants Октябрь")
    }

    @Test("Ukrainian too")
    func ukrainianIsCapitalised() throws {
        let name = october("uk_UA")
        let first = try #require(name.first)
        #expect(first.isUppercase, "Got \(name)")
    }

    @Test("English is unchanged")
    func englishIsUnchanged() {
        #expect(october("en_GB") == "October")
    }

    @Test("The year comes along when asked for")
    func theYearCanBeIncluded() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let date = calendar.date(from: DateComponents(year: 2024, month: 3, day: 1)) ?? .now
        let name = MonthName.standalone(
            date, includingYear: true, calendar: calendar, locale: Locale(identifier: "en_GB")
        )
        #expect(name.contains("2024"))
        #expect(name.contains("March"))
    }
}
