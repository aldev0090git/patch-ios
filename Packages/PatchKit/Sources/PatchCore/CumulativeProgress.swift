import Foundation

/// How a long-run target is going. "12 000 of 100 000, 38 days left."
public struct CumulativeProgress: Hashable, Sendable {
    public let total: Decimal
    public let target: Decimal
    public let deadline: Date?
    /// Whole days from today to the deadline. Zero on the day itself,
    /// negative once it has passed, nil when there is no deadline.
    public let daysRemaining: Int?

    public init(total: Decimal, target: Decimal, deadline: Date?, daysRemaining: Int?) {
        self.total = total
        self.target = target
        self.deadline = deadline
        self.daysRemaining = daysRemaining
    }

    public var isReached: Bool { total >= target }

    /// Clamped, so a target beaten by half does not draw a bar off the screen.
    public var fraction: Double {
        guard target > .zero else { return isReached ? 1 : 0 }
        return min(max(total.doubleValue / target.doubleValue, 0), 1)
    }

    public var remaining: Decimal { max(.zero, target - total) }

    /// A deadline is only "missed" if the target was not met by then. Reaching
    /// it early and then letting the date pass is a success, not a failure.
    public var isOverdue: Bool {
        guard let daysRemaining, !isReached else { return false }
        return daysRemaining < 0
    }

    /// What must be put aside each remaining day to still make it.
    ///
    /// Nil without a deadline, and nil once the date has passed — there is no
    /// per-day number that rescues a date already gone.
    public var requiredPerRemainingDay: Decimal? {
        guard let daysRemaining, !isReached else { return nil }
        guard daysRemaining > 0 else { return nil }
        return remaining / Decimal(daysRemaining)
    }
}

extension ProgressCalculator {
    /// Progress toward a goal's long-run target, if it has one.
    public func cumulativeProgress(
        for goal: Goal,
        entries: [Entry],
        asOf date: Date = .now
    ) -> CumulativeProgress? {
        guard let target = goal.cumulativeTarget else { return nil }

        let daysRemaining = goal.cumulativeDeadline.map { deadline in
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: date),
                to: calendar.startOfDay(for: deadline)
            ).day ?? 0
        }

        return CumulativeProgress(
            total: cumulativeTotal(for: goal, entries: entries, upTo: date),
            target: target,
            deadline: goal.cumulativeDeadline,
            daysRemaining: daysRemaining
        )
    }
}
