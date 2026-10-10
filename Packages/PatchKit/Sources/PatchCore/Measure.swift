import Foundation

/// The kind of quantity a goal accumulates.
///
/// Every amount in Patch is stored in its kind's *canonical* unit, so totals,
/// comparisons and sync never depend on how a value happens to be displayed.
/// Formatting back into minutes, glasses or kilometres is a presentation concern.
public enum MeasureKind: String, Codable, Sendable, CaseIterable, Hashable {
    /// Stored in seconds. "Read for 20 minutes."
    case duration
    /// Stored as a dimensionless count. "100 push-ups", "10 000 steps".
    case count
    /// Stored in millilitres. "Drink 2 litres of water."
    case volume
    /// Stored in metres. "Walk 5 km."
    case distance
    /// Stored in major currency units. "Put aside 100 UAH."
    case currency
}

extension MeasureKind {
    /// Short name of the unit amounts are stored in. Diagnostics only.
    public var canonicalUnit: String {
        switch self {
        case .duration: "s"
        case .count: "x"
        case .volume: "ml"
        case .distance: "m"
        case .currency: "major unit"
        }
    }
}

/// What a goal asks of a single scheduled day.
public struct Measure: Hashable, Sendable, Codable {
    public var kind: MeasureKind
    /// Target for one scheduled day, in `kind`'s canonical unit.
    public var dailyTarget: Decimal
    /// Amount added by one tap of the quick-add control, in canonical units.
    public var quickAdd: Decimal

    public init(kind: MeasureKind, dailyTarget: Decimal, quickAdd: Decimal) {
        self.kind = kind
        self.dailyTarget = max(.zero, dailyTarget)
        self.quickAdd = max(.zero, quickAdd)
    }
}

// MARK: - Convenience constructors
//
// These keep call sites readable and stop canonical-unit conversions from
// leaking into feature code.

extension Measure {
    /// "Read for 20 minutes", logged in 5-minute taps.
    public static func minutes(_ target: Int, quickAdd: Int = 5) -> Measure {
        Measure(kind: .duration,
                dailyTarget: Decimal(target * 60),
                quickAdd: Decimal(quickAdd * 60))
    }

    /// "100 push-ups", logged in tens.
    public static func times(_ target: Int, quickAdd: Int = 1) -> Measure {
        Measure(kind: .count, dailyTarget: Decimal(target), quickAdd: Decimal(quickAdd))
    }

    /// "2 litres of water", logged a 250 ml glass at a time.
    public static func millilitres(_ target: Int, quickAdd: Int = 250) -> Measure {
        Measure(kind: .volume, dailyTarget: Decimal(target), quickAdd: Decimal(quickAdd))
    }

    /// "Walk 10 000 steps" — a count, but usually filled in from HealthKit.
    public static func steps(_ target: Int) -> Measure {
        Measure(kind: .count, dailyTarget: Decimal(target), quickAdd: Decimal(500))
    }

    /// "Put aside 100 UAH today."
    public static func money(_ target: Decimal, quickAdd: Decimal) -> Measure {
        Measure(kind: .currency, dailyTarget: target, quickAdd: quickAdd)
    }

    /// A zero allowance, for use with ``Direction/atMost``.
    ///
    /// Valid, and the domain handles it, but no template ships with one: a goal
    /// that succeeds from midnight gives the user nothing to do except record a
    /// failure. Prefer modelling such goals as a daily confirmation, the way
    /// ``GoalTemplateCatalog/quitSmoking`` does.
    public static var clean: Measure {
        Measure(kind: .count, dailyTarget: .zero, quickAdd: 1)
    }
}
