import Foundation

/// Counts consecutive successful days.
public struct StreakCalculator: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Length of the streak running up to `asOf`.
    ///
    /// Two deliberate rules:
    ///
    /// - **Unscheduled days are skipped**, never broken. A weekday-only habit
    ///   keeps its streak across the weekend.
    /// - **Today is forgiving.** If today is scheduled but not yet done, the
    ///   streak is measured from yesterday instead of being shown as zero.
    ///   Resetting someone's streak at 00:01, before they have had any chance
    ///   to act, is punishing them for the clock rather than their behaviour.
    public func currentStreak(for goal: Goal, entries: [Entry], asOf: Date = .now) -> Int {
        let totals = ProgressCalculator(calendar: calendar).totalsByDay(for: goal, entries: entries)
        let earliest = calendar.startOfDay(for: goal.createdAt)
        var day = calendar.startOfDay(for: asOf)
        var streak = 0
        var isToday = true

        while day >= earliest {
            defer {
                isToday = false
                day = calendar.date(byAdding: .day, value: -1, to: day) ?? .distantPast
            }
            guard goal.schedule.isScheduled(on: day, calendar: calendar) else { continue }

            if isAchieved(goal: goal, total: totals[day] ?? .zero, on: day) {
                streak += 1
            } else if isToday {
                continue // still time left today
            } else {
                break
            }
        }
        return streak
    }

    /// The longest run of successful scheduled days in the goal's history.
    public func longestStreak(for goal: Goal, entries: [Entry], asOf: Date = .now) -> Int {
        let totals = ProgressCalculator(calendar: calendar).totalsByDay(for: goal, entries: entries)
        var day = calendar.startOfDay(for: goal.createdAt)
        let last = calendar.startOfDay(for: asOf)
        var best = 0
        var run = 0

        while day <= last {
            defer { day = calendar.date(byAdding: .day, value: 1, to: day) ?? .distantFuture }
            guard goal.schedule.isScheduled(on: day, calendar: calendar) else { continue }

            if isAchieved(goal: goal, total: totals[day] ?? .zero, on: day) {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        return best
    }

    /// Judged against the target in force on that day, not today's — raising
    /// a target must not retroactively break a streak that was genuinely met.
    private func isAchieved(goal: Goal, total: Decimal, on day: Date) -> Bool {
        switch goal.direction {
        case .atLeast: total >= goal.dailyTarget(on: day, calendar: calendar)
        case .atMost: total <= goal.dailyTarget(on: day, calendar: calendar)
        }
    }
}
