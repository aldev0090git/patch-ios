import Foundation

/// Turns raw entries into day-by-day progress.
///
/// Takes its `Calendar` by injection rather than reaching for `.current`, so
/// tests can pin a timezone and first-weekday and stay deterministic wherever
/// CI happens to run.
public struct ProgressCalculator: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Totals for a goal, keyed by start-of-day.
    ///
    /// Built once and reused rather than re-filtering per day, which keeps a
    /// year of calendar cells linear rather than quadratic.
    public func totalsByDay(for goal: Goal, entries: [Entry]) -> [Date: Decimal] {
        var totals: [Date: Decimal] = [:]
        for entry in entries where entry.goalID == goal.id {
            let day = calendar.startOfDay(for: entry.loggedAt)
            totals[day, default: .zero] += entry.amount
        }
        return totals
    }

    public func progress(for goal: Goal, entries: [Entry], on date: Date) -> DayProgress {
        progress(for: goal, totals: totalsByDay(for: goal, entries: entries), on: date)
    }

    /// Variant taking precomputed totals, for when you are walking many days.
    public func progress(for goal: Goal, totals: [Date: Decimal], on date: Date) -> DayProgress {
        let day = calendar.startOfDay(for: date)
        return DayProgress(
            date: day,
            total: totals[day] ?? .zero,
            target: goal.measure.dailyTarget,
            direction: goal.direction,
            isScheduled: goal.schedule.isScheduled(on: day, calendar: calendar)
        )
    }

    /// Progress for every day in a range, oldest first. Powers the calendar and charts.
    public func progress(for goal: Goal, entries: [Entry], from start: Date, to end: Date) -> [DayProgress] {
        let totals = totalsByDay(for: goal, entries: entries)
        var day = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        var result: [DayProgress] = []
        while day <= last {
            result.append(progress(for: goal, totals: totals, on: day))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// Everything logged toward a goal up to and including `date` — the number
    /// a cumulative target like "save 20 000 UAH" is measured against.
    public func cumulativeTotal(for goal: Goal, entries: [Entry], upTo date: Date = .now) -> Decimal {
        let cutoff = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: date) ?? date)
        return entries
            .filter { $0.goalID == goal.id && $0.loggedAt < cutoff }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }
}
