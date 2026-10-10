import Foundation

/// The values a manual-entry picker should offer for a goal.
///
/// Runs from one step up to the goal's daily target, so completing the day in
/// a single entry is always reachable. Logging *more* than the target in one
/// go is deliberately not offered: it is rare, and a picker long enough to
/// cover it is worse for the common case. Two entries cover it.
public enum ManualAmounts {
    /// Roughly the most options a wheel picker stays pleasant to spin.
    private static let maximumOptions = 40

    /// Candidate step sizes per kind, in canonical units, coarsest last.
    private static func steps(for kind: MeasureKind) -> [Decimal] {
        switch kind {
        case .duration: [60, 300, 900, 1800]          // 1m, 5m, 15m, 30m
        case .count: [1, 2, 5, 10, 25, 50, 100, 500]
        case .volume: [10, 25, 50, 100, 250]
        case .distance: [50, 100, 250, 500, 1000]
        case .currency: [1, 5, 10, 25, 50, 100]
        }
    }

    /// Ascending amounts in canonical units, or empty when the goal has no
    /// target to work towards.
    public static func options(for measure: Measure) -> [Decimal] {
        let target = measure.dailyTarget
        guard target > .zero else { return [] }

        let step = self.step(for: measure.kind, target: target)
        guard step > .zero else { return [] }

        var amounts: [Decimal] = []
        var amount = step
        while amount <= target {
            amounts.append(amount)
            amount += step
        }
        // A target that is not a whole number of steps still deserves to be
        // reachable: "20 of 20" must be in the list.
        if amounts.last != target {
            amounts.append(target)
        }
        return amounts
    }

    /// The finest step that keeps the list within ``maximumOptions``.
    private static func step(for kind: MeasureKind, target: Decimal) -> Decimal {
        let candidates = steps(for: kind)
        for candidate in candidates where target / candidate <= Decimal(maximumOptions) {
            return candidate
        }
        return candidates.last ?? 1
    }
}
