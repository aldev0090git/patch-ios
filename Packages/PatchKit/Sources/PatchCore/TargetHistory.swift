import Foundation

/// A daily target, and the day it started applying.
public struct TargetChange: Hashable, Sendable, Codable, Comparable {
    /// Start of the first day this target applies to.
    public let effectiveFrom: Date
    public let dailyTarget: Decimal

    public init(effectiveFrom: Date, dailyTarget: Decimal) {
        self.effectiveFrom = effectiveFrom
        self.dailyTarget = max(.zero, dailyTarget)
    }

    public static func < (lhs: TargetChange, rhs: TargetChange) -> Bool {
        lhs.effectiveFrom < rhs.effectiveFrom
    }
}

extension Goal {
    /// What this goal asked for on a given day.
    ///
    /// Raising "read 20 minutes" to an hour must not turn a month of finished
    /// days into a month of failures. Each day is judged against the target
    /// that was actually in force, so history stays true and only the days
    /// from the change onward are held to the new number.
    ///
    /// A goal with no recorded changes has only ever had one target, so
    /// ``Measure/dailyTarget`` answers for every day.
    public func dailyTarget(on date: Date, calendar: Calendar = .current) -> Decimal {
        guard !targetHistory.isEmpty else { return measure.dailyTarget }

        let day = calendar.startOfDay(for: date)
        let ordered = targetHistory.sorted()

        // Before the first recorded target, the first one is the best answer
        // available — the alternative is judging a day against nothing.
        guard let applicable = ordered.last(where: { $0.effectiveFrom <= day }) else {
            return ordered[0].dailyTarget
        }
        return applicable.dailyTarget
    }

    /// A copy of this goal with a new daily target from `changedOn` onward.
    ///
    /// The first change also records what the target *was*, because nothing
    /// else does: until a goal's target changes there is no history to keep,
    /// and afterwards the old value would otherwise be lost.
    public func withTarget(
        _ newTarget: Decimal,
        changedOn date: Date = .now,
        calendar: Calendar = .current
    ) -> Goal {
        let clamped = max(Decimal.zero, newTarget)
        guard clamped != measure.dailyTarget else { return self }

        let day = calendar.startOfDay(for: date)
        var history = targetHistory

        if history.isEmpty {
            history.append(TargetChange(
                effectiveFrom: calendar.startOfDay(for: createdAt),
                dailyTarget: measure.dailyTarget
            ))
        }

        // Changing your mind twice in one day leaves one entry, not two.
        history.removeAll { $0.effectiveFrom == day }
        history.append(TargetChange(effectiveFrom: day, dailyTarget: clamped))

        var updated = self
        updated.measure = Measure(kind: measure.kind, dailyTarget: clamped)
        updated.targetHistory = history.sorted()
        return updated
    }
}
