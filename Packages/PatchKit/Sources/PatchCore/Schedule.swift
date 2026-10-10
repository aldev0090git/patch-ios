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

    public func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .daily:
            true
        case .daysOfWeek(let days):
            Weekday(rawValue: calendar.component(.weekday, from: date))
                .map(days.contains) ?? false
        }
    }
}

extension Schedule {
    public static let weekdays = Schedule.daysOfWeek([.monday, .tuesday, .wednesday, .thursday, .friday])
    public static let weekends = Schedule.daysOfWeek([.saturday, .sunday])
}
