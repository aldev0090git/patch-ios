import Foundation
import PatchCore

/// Names the window the statistics screen is showing.
///
/// `nonisolated` for the same reason as `MeasureFormatter`: pure computation,
/// and tests must be able to call it off the main actor.
nonisolated enum PeriodFormatter {
    /// A short label for the current window — what sits between the two arrows.
    ///
    /// Relative names win where they exist: someone looking at this week wants
    /// to read "This week", not a date range they have to decode.
    static func title(
        _ selection: PeriodSelection,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent,
        asOf: Date = .now
    ) -> String {
        let range = selection.period.range(in: calendar)
        let today = calendar.startOfDay(for: asOf)

        switch selection.kind {
        case .day:
            if calendar.isDate(range.lowerBound, inSameDayAs: today) {
                return String(localized: "Today")
            }
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
               calendar.isDate(range.lowerBound, inSameDayAs: yesterday) {
                return String(localized: "Yesterday")
            }
            return range.lowerBound.formatted(
                .dateTime.day().month(.abbreviated).year().locale(locale)
            )

        case .week:
            if range.contains(today) { return String(localized: "This week") }
            return span(range, calendar: calendar, locale: locale)

        case .month:
            if range.contains(today) { return String(localized: "This month") }
            // The year is dropped within the current year — "March" reads
            // better than "March 2026" when 2026 is the only year on screen.
            let sameYear = calendar.component(.year, from: range.lowerBound)
                == calendar.component(.year, from: today)
            return range.lowerBound.formatted(
                sameYear
                    ? .dateTime.month(.wide).locale(locale)
                    : .dateTime.month(.wide).year().locale(locale)
            )

        case .year:
            if range.contains(today) { return String(localized: "This year") }
            return range.lowerBound.formatted(.dateTime.year().locale(locale))

        case .custom:
            return span(range, calendar: calendar, locale: locale)
        }
    }

    /// "6–12 Oct", or a single date when both ends land on the same day.
    private static func span(
        _ range: ClosedRange<Date>,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        let style = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(locale)
        if calendar.isDate(range.lowerBound, inSameDayAs: range.upperBound) {
            return range.lowerBound.formatted(style)
        }
        return "\(range.lowerBound.formatted(style)) – \(range.upperBound.formatted(style))"
    }
}
