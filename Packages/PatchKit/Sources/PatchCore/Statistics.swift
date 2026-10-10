import Foundation

/// A window to report over.
public enum StatisticsPeriod: Hashable, Sendable {
    case day(Date)
    case week(Date)
    case month(Date)
    case year(Date)
    case custom(ClosedRange<Date>)

    /// Inclusive range of start-of-day dates covered by this period.
    public func range(in calendar: Calendar) -> ClosedRange<Date> {
        switch self {
        case .day(let date):
            let start = calendar.startOfDay(for: date)
            return start...start
        case .week(let date):
            return Self.range(of: .weekOfYear, containing: date, in: calendar)
        case .month(let date):
            return Self.range(of: .month, containing: date, in: calendar)
        case .year(let date):
            return Self.range(of: .year, containing: date, in: calendar)
        case .custom(let range):
            let lower = calendar.startOfDay(for: range.lowerBound)
            let upper = calendar.startOfDay(for: range.upperBound)
            return lower...max(lower, upper)
        }
    }

    private static func range(
        of component: Calendar.Component,
        containing date: Date,
        in calendar: Calendar
    ) -> ClosedRange<Date> {
        guard let interval = calendar.dateInterval(of: component, for: date) else {
            let day = calendar.startOfDay(for: date)
            return day...day
        }
        let start = calendar.startOfDay(for: interval.start)
        let last = calendar.startOfDay(for: interval.end.addingTimeInterval(-1))
        return start...max(start, last)
    }
}

/// How one goal did over a period.
public struct PeriodStatistics: Hashable, Sendable {
    public let range: ClosedRange<Date>
    /// Scheduled days that have already been settled. Excludes days before the
    /// goal existed, days still in the future, and an unfinished today.
    public let scheduledDays: Int
    public let completedDays: Int
    /// Everything logged in the period, in canonical units.
    public let total: Decimal
    public let currentStreak: Int
    public let longestStreak: Int
    /// The strongest day in the period, if any day was scheduled.
    public let best: DayProgress?
    /// True when today falls in this period and is scheduled but not yet done.
    /// It is counted as neither completed nor missed — there is still time.
    public let hasPendingToday: Bool

    public var missedDays: Int { max(0, scheduledDays - completedDays) }

    public var completionRate: Double {
        scheduledDays > 0 ? Double(completedDays) / Double(scheduledDays) : 0
    }
}

/// How *all* goals did on a single day. Powers the calendar grid and the widget.
public struct DaySummary: Hashable, Sendable {
    public let date: Date
    public let scheduled: Int
    public let completed: Int

    public var remaining: Int { max(0, scheduled - completed) }

    public var fraction: Double {
        scheduled > 0 ? Double(completed) / Double(scheduled) : 0
    }
}

public struct StatisticsCalculator: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Statistics for one goal over a period.
    ///
    /// Three kinds of day are deliberately excluded from the denominator, so
    /// "missed" means genuinely missed:
    ///
    /// - days before the goal was created — you cannot miss a goal you had not
    ///   set yet, which otherwise makes every new goal open on a wall of red
    /// - days still in the future
    /// - today, while it is still unfinished
    public func statistics(
        for goal: Goal,
        entries: [Entry],
        period: StatisticsPeriod,
        asOf: Date = .now
    ) -> PeriodStatistics {
        let range = period.range(in: calendar)
        let progress = ProgressCalculator(calendar: calendar)
        let totals = progress.totalsByDay(for: goal, entries: entries)

        let today = calendar.startOfDay(for: asOf)
        let created = calendar.startOfDay(for: goal.createdAt)
        let start = max(range.lowerBound, created)
        let end = min(range.upperBound, today)

        var scheduledDays = 0
        var completedDays = 0
        var total = Decimal.zero
        var best: DayProgress?
        var hasPendingToday = false

        var day = start
        while day <= end {
            defer { day = calendar.date(byAdding: .day, value: 1, to: day) ?? .distantFuture }

            total += totals[day] ?? .zero
            let dayProgress = progress.progress(for: goal, totals: totals, on: day)
            guard dayProgress.isScheduled else { continue }

            if dayProgress.isAchieved {
                scheduledDays += 1
                completedDays += 1
            } else if day == today {
                hasPendingToday = true // still time left — neither done nor missed
            } else {
                scheduledDays += 1
            }

            if best == nil || dayProgress.total > (best?.total ?? .zero) {
                best = dayProgress
            }
        }

        let streaks = StreakCalculator(calendar: calendar)
        return PeriodStatistics(
            range: range,
            scheduledDays: scheduledDays,
            completedDays: completedDays,
            total: total,
            currentStreak: streaks.currentStreak(for: goal, entries: entries, asOf: asOf),
            longestStreak: streaks.longestStreak(for: goal, entries: entries, asOf: asOf),
            best: best,
            hasPendingToday: hasPendingToday
        )
    }

    /// How many of the day's goals are done. Archived goals are ignored.
    public func summary(for goals: [Goal], entries: [Entry], on date: Date) -> DaySummary {
        let day = calendar.startOfDay(for: date)
        let progress = ProgressCalculator(calendar: calendar)

        var scheduled = 0
        var completed = 0

        for goal in goals where !goal.isArchived && calendar.startOfDay(for: goal.createdAt) <= day {
            let dayProgress = progress.progress(for: goal, entries: entries, on: day)
            guard dayProgress.isScheduled else { continue }
            scheduled += 1
            if dayProgress.isAchieved { completed += 1 }
        }

        return DaySummary(date: day, scheduled: scheduled, completed: completed)
    }

    /// One summary per day across a range, oldest first — the calendar month grid.
    public func summaries(
        for goals: [Goal],
        entries: [Entry],
        in range: ClosedRange<Date>
    ) -> [DaySummary] {
        var day = calendar.startOfDay(for: range.lowerBound)
        let last = calendar.startOfDay(for: range.upperBound)
        var result: [DaySummary] = []
        while day <= last {
            result.append(summary(for: goals, entries: entries, on: day))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }
}
