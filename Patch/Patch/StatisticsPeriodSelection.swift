import Foundation
import PatchCore

// Both types below are `nonisolated`: pure values over Foundation, and the
// formatter and the tests need them off the main actor, which the app target
// otherwise implies for everything.

/// Which kind of window the statistics screen is showing.
///
/// Separate from ``StatisticsPeriod`` because the screen needs something the
/// domain type has no reason to carry: a stable identity to drive a picker,
/// and a notion of stepping to the previous or next window of the same kind.
nonisolated enum PeriodKind: String, CaseIterable, Identifiable, Hashable {
    case day, week, month, year, custom

    var id: String { rawValue }

    /// The calendar unit one tap of the back/forward arrow moves by.
    /// Custom ranges do not step — the user picked the ends themselves.
    var stepComponent: Calendar.Component? {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        case .custom: nil
        }
    }

    var title: String {
        switch self {
        case .day: String(localized: "Day")
        case .week: String(localized: "Week")
        case .month: String(localized: "Month")
        case .year: String(localized: "Year")
        case .custom: String(localized: "Custom")
        }
    }
}

/// The screen's current window: a kind, plus where it sits in time.
nonisolated struct PeriodSelection: Hashable {
    var kind: PeriodKind = .week
    /// Any date inside the window. Stepping moves this, not the bounds.
    var anchor: Date = .now
    /// Only meaningful while `kind` is `.custom`.
    var customStart: Date = .now
    var customEnd: Date = .now

    var period: StatisticsPeriod {
        switch kind {
        case .day: .day(anchor)
        case .week: .week(anchor)
        case .month: .month(anchor)
        case .year: .year(anchor)
        // Guarding the order here rather than trusting the two pickers means a
        // backwards range shows one day instead of silently showing nothing.
        case .custom: .custom(min(customStart, customEnd)...max(customStart, customEnd))
        }
    }

    /// Moves one window back or forward. A no-op for custom ranges.
    mutating func step(by delta: Int, calendar: Calendar) {
        guard let component = kind.stepComponent,
              let moved = calendar.date(byAdding: component, value: delta, to: anchor)
        else { return }
        anchor = moved
    }

    /// False once the window already contains today: there is nothing to see
    /// in the future, and an arrow that walks into empty months is a trap.
    func canStepForward(calendar: Calendar, asOf: Date = .now) -> Bool {
        guard kind.stepComponent != nil else { return false }
        return period.range(in: calendar).upperBound < calendar.startOfDay(for: asOf)
    }
}
