import Foundation

/// Day of the week, matching `Calendar`'s 1-based `.weekday` component.
public enum Weekday: Int, Codable, Sendable, CaseIterable, Hashable, Comparable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Which days a goal is expected on.
///
/// Days the goal is *not* scheduled for are not failures — they are skipped
/// entirely, including by streak counting. A weekday-only gym habit should not
/// lose its streak every Saturday.
public enum Schedule: Hashable, Sendable, Codable {
    case daily
    case daysOfWeek(Set<Weekday>)
    /// Dates in the month, 1 to 31. For things that happen on a date rather
    /// than a rhythm — money put aside when the salary lands, on the 1st, or
    /// on the 1st and the 15th.
    case daysOfMonth(Set<Int>)

    public func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .daily:
            return true
        case .daysOfWeek(let days):
            return Weekday(rawValue: calendar.component(.weekday, from: date))
                .map(days.contains) ?? false
        case .daysOfMonth(let days):
            return isScheduledDate(date, in: days, calendar: calendar)
        }
    }

    /// A date past the end of a short month lands on its last day.
    ///
    /// Someone paid on the 31st is still paid in February. Dropping the month
    /// instead would silently skip it, and skipped days are invisible — they
    /// do not even break a streak.
    private func isScheduledDate(_ date: Date, in days: Set<Int>, calendar: Calendar) -> Bool {
        let day = calendar.component(.day, from: date)
        if days.contains(day) { return true }

        guard let range = calendar.range(of: .day, in: .month, for: date),
              let lastDay = range.last, day == lastDay
        else { return false }
        return days.contains { $0 > lastDay }
    }
}

extension Schedule {
    public static let weekdays = Schedule.daysOfWeek([.monday, .tuesday, .wednesday, .thursday, .friday])
    public static let weekends = Schedule.daysOfWeek([.saturday, .sunday])
}
