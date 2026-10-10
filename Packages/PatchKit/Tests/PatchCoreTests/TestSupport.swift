import Foundation
@testable import PatchCore

// Force-unwrapping is deliberate here: these are hard-coded, known-valid date
// components. If they ever fail to build a Date the fixture itself is broken,
// and crashing loudly in the test helper is the clearest possible signal.
// swiftlint:disable force_unwrapping

/// A calendar pinned to UTC with a Monday first weekday, so these tests behave
/// identically on a laptop in Kyiv and on a CI runner in another timezone.
func fixedCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2
    return calendar
}

/// Midday on the given date, so nothing accidentally depends on a day-boundary
/// rounding bug.
func day(_ year: Int, _ month: Int, _ dayOfMonth: Int, hour: Int = 12) -> Date {
    let components = DateComponents(year: year, month: month, day: dayOfMonth, hour: hour)
    return fixedCalendar().date(from: components)!
}

// swiftlint:enable force_unwrapping
