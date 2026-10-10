import Foundation

extension Decimal {
    /// Lossy conversion for display maths only — never for storage or totals.
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}

/// How one goal stands on one day.
public struct DayProgress: Hashable, Sendable {
    /// Start of the day this describes, in the calculating calendar.
    public let date: Date
    public let total: Decimal
    public let target: Decimal
    public let direction: Direction
    /// Whether the goal is expected on this day at all.
    public let isScheduled: Bool

    public init(date: Date, total: Decimal, target: Decimal, direction: Direction, isScheduled: Bool) {
        self.date = date
        self.total = total
        self.target = target
        self.direction = direction
        self.isScheduled = isScheduled
    }

    /// Whether the day counts as done.
    ///
    /// Unscheduled days are never "achieved" — they are not part of the goal.
    /// Streak counting skips them rather than treating them as failures.
    public var isAchieved: Bool {
        guard isScheduled else { return false }
        switch direction {
        case .atLeast: return total >= target
        case .atMost: return total <= target
        }
    }

    /// 0...1 completion, for rings and bars.
    ///
    /// For ``Direction/atMost`` this is deliberately binary: a day spent inside
    /// your limit is complete, a day spent over it is not. Use ``budgetUsed``
    /// when you want to show how much of an allowance has been spent.
    public var fraction: Double {
        switch direction {
        case .atLeast:
            guard target > .zero else { return total > .zero ? 1 : 0 }
            return min(1, max(0, total.doubleValue / target.doubleValue))
        case .atMost:
            return isAchieved ? 1 : 0
        }
    }

    /// For ``Direction/atMost`` goals with a non-zero allowance, the share of
    /// that allowance used so far. May exceed 1. `nil` when it has no meaning.
    public var budgetUsed: Double? {
        guard direction == .atMost, target > .zero else { return nil }
        return max(0, total.doubleValue / target.doubleValue)
    }

    /// How much is still allowed or still needed, in canonical units.
    public var remaining: Decimal { max(.zero, target - total) }
}
