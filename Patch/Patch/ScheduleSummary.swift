import Foundation
import PatchCore

/// A schedule in words, for a list that has no room to draw a week.
///
/// In the app layer rather than `PatchCore` because it is entirely about
/// language: weekday names come from the reader's calendar, and the joining
/// words from their locale.
enum ScheduleSummary {
    static func text(for schedule: Schedule, calendar: Calendar = .current) -> String {
        switch schedule {
        case .daily:
            return String(localized: "Every day")

        case .daysOfWeek(let days):
            guard !days.isEmpty else { return String(localized: "No days chosen") }
            guard days.count < 7 else { return String(localized: "Every day") }
            // Ordered from the reader's first weekday, not from Sunday, so
            // the list reads in the order their week runs.
            let ordered = (0..<7).compactMap { offset in
                Weekday(rawValue: (calendar.firstWeekday - 1 + offset) % 7 + 1)
            }
            let names = ordered
                .filter(days.contains)
                .map { calendar.shortWeekdaySymbols[$0.rawValue - 1] }
            return ListFormatter.localizedString(byJoining: names)

        case .daysOfMonth(let dates):
            guard !dates.isEmpty else { return String(localized: "No dates chosen") }
            let numbers = dates.sorted().map { $0.formatted(.number) }
            return ListFormatter.localizedString(byJoining: numbers)
        }
    }
}
