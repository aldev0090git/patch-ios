import Foundation

/// One suggested amount on the logging screen.
public struct QuickAddOption: Identifiable, Hashable, Sendable {
    /// Amount in the measure's canonical unit.
    public let amount: Decimal
    public var id: Decimal { amount }

    public init(amount: Decimal) {
        self.amount = amount
    }
}

/// Picks sensible one-tap amounts for logging against a goal.
///
/// Asking someone to spin a picker to record a glass of water is the fastest
/// way to make them stop logging. The suggestions scale with the target, so a
/// 100 push-up goal offers 5/10/20/50 while a 20-push-up goal offers 1/2/5/10,
/// and both land on round numbers a person would actually say out loud.
public enum QuickAddSuggestions {
    /// Fractions of the daily target to offer, smallest first.
    ///
    /// Three, so the row can hold them at equal width alongside a manual
    /// option and still read cleanly on a narrow phone. A quarter is the
    /// smallest useful bite — finer than that and a one-hour reading goal
    /// starts suggesting "1 minute", which nobody taps. The last fraction is
    /// the whole target, so finishing in one sitting stays one tap.
    private static let fractions: [(numerator: Int, denominator: Int)] = [
        (1, 4), (1, 2), (1, 1)
    ]

    /// Round numbers people actually use, per kind, in canonical units.
    private static func ladder(for kind: MeasureKind) -> [Decimal] {
        switch kind {
        case .duration: // 1m, 5m, 10m, 15m, 20m, 30m, 45m, 1h, 1.5h, 2h, 3h
            [60, 300, 600, 900, 1200, 1800, 2700, 3600, 5400, 7200, 10800]
        case .count:
            [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 5000, 10000]
        case .volume: // a small glass through to a large bottle
            [100, 150, 200, 250, 330, 500, 750, 1000, 1500, 2000]
        case .distance: // metres
            [100, 250, 500, 1000, 2000, 5000, 10000, 21097, 42195]
        case .currency: // no fixed ladder — rounded by magnitude instead
            []
        }
    }

    /// Up to four suggestions for this measure, smallest first.
    ///
    /// A goal with a zero target is an abstinence goal: the only thing worth
    /// logging is a single slip.
    public static func options(for measure: Measure, limit: Int = 3) -> [QuickAddOption] {
        guard measure.dailyTarget > .zero else {
            return [QuickAddOption(amount: 1)]
        }

        let target = measure.dailyTarget
        let raw = fractions.map { fraction in
            (target * Decimal(fraction.numerator)) / Decimal(fraction.denominator)
        }

        let snapped = raw.map { value in
            snap(value, kind: measure.kind)
        }

        // Dedupe while preserving order, drop anything that rounded to nothing.
        var seen: Set<Decimal> = []
        let unique = snapped.filter { value in
            value > .zero && seen.insert(value).inserted
        }

        return unique.prefix(limit).map(QuickAddOption.init(amount:))
    }

    /// Nudges a computed amount onto the nearest value a person would say.
    private static func snap(_ value: Decimal, kind: MeasureKind) -> Decimal {
        let steps = ladder(for: kind)
        guard !steps.isEmpty else { return roundedByMagnitude(value) }

        return steps.min { lhs, rhs in
            (lhs - value).magnitude < (rhs - value).magnitude
        } ?? value
    }

    /// Currency has no universal ladder — 50 is a round number in one currency
    /// and loose change in another — so round relative to the amount's own size.
    private static func roundedByMagnitude(_ value: Decimal) -> Decimal {
        let step: Decimal
        switch value {
        case ..<10: step = 1
        case ..<100: step = 5
        case ..<1000: step = 10
        case ..<10000: step = 50
        default: step = 100
        }
        var scaled = value / step
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return rounded * step
    }
}
