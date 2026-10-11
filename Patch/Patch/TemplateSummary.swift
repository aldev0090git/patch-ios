import Foundation
import PatchCore

/// One line describing what a template commits you to.
///
/// `nonisolated` for the same reason as the other formatters: pure computation
/// over value types, and the tests must be able to call it off the main actor.
nonisolated enum TemplateSummary {
    static func text(
        for template: GoalTemplate,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let amount = MeasureFormatter.short(
            template.measure.dailyTarget,
            measure: template.measure,
            locale: locale
        )
        // A once-a-day goal has no interesting amount — "1 every day" reads
        // like a bug. The schedule is the whole story for those.
        let isConfirmation = template.measure.kind == .count
            && template.measure.dailyTarget == 1

        switch template.schedule {
        case .daily:
            return isConfirmation
                ? String(localized: "Every day")
                : String(localized: "\(amount) every day")
        case .daysOfWeek(let days):
            let names = weekdayNames(days, calendar: calendar, locale: locale)
            return isConfirmation ? names : String(localized: "\(amount) on \(names)")
        }
    }

    /// Weekday names in the reader's own week order — a list starting on Monday
    /// is wrong for a locale whose week starts on Sunday.
    private static func weekdayNames(
        _ days: Set<Weekday>,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        var symbols = calendar.shortStandaloneWeekdaySymbols
        if symbols.count == 7 {
            let first = calendar.firstWeekday - 1
            symbols = Array(symbols[first...] + symbols[..<first])
        }

        let ordered = Weekday.allCases
            .sorted { lhs, rhs in
                let offset = { (day: Weekday) in
                    (day.rawValue - calendar.firstWeekday + 7) % 7
                }
                return offset(lhs) < offset(rhs)
            }
            .filter(days.contains)

        let names = ordered.compactMap { day -> String? in
            let index = (day.rawValue - calendar.firstWeekday + 7) % 7
            return symbols.indices.contains(index) ? symbols[index] : nil
        }

        return ListFormatter.localizedString(byJoining: names)
    }
}
