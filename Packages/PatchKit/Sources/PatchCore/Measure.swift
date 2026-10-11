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
    /// ISO 4217 code, for ``MeasureKind/currency`` only.
    ///
    /// Money is the one kind whose canonical unit is not universal: 100 is a
    /// different amount in dollars, euros and hryvnia, and a goal to save
    /// money is meaningless without saying which. `nil` means "whatever this
    /// phone uses", which is right for a goal created before the question was
    /// ever asked.
    public var currencyCode: String?

    public init(kind: MeasureKind, dailyTarget: Decimal, currencyCode: String? = nil) {
        self.kind = kind
        self.dailyTarget = max(.zero, dailyTarget)
        // Carried only where it means something, so two goals cannot differ by
        // a field one of them does not use.
        self.currencyCode = kind == .currency ? currencyCode : nil
    }
}

// MARK: - Convenience constructors
//
// These keep call sites readable and stop canonical-unit conversions from
// leaking into feature code.

extension Measure {
    /// "Read for 20 minutes."
    public static func minutes(_ target: Int) -> Measure {
        Measure(kind: .duration, dailyTarget: Decimal(target * 60))
    }

    /// "100 push-ups."
    public static func times(_ target: Int) -> Measure {
        Measure(kind: .count, dailyTarget: Decimal(target))
    }

    /// "2 litres of water."
    public static func millilitres(_ target: Int) -> Measure {
        Measure(kind: .volume, dailyTarget: Decimal(target))
    }

    /// "Walk 10 000 steps" — a count, but usually filled in from HealthKit.
    public static func steps(_ target: Int) -> Measure {
        Measure(kind: .count, dailyTarget: Decimal(target))
    }

    /// "Put aside 100 UAH today."
    public static func money(_ target: Decimal, currencyCode: String? = nil) -> Measure {
        Measure(kind: .currency, dailyTarget: target, currencyCode: currencyCode)
    }

    /// A zero allowance, for use with ``Direction/atMost``.
    ///
    /// Valid, and the domain handles it, but no template ships with one: a goal
    /// that succeeds from midnight gives the user nothing to do except record a
    /// failure. Prefer modelling such goals as a daily confirmation, the way
    /// ``GoalTemplateCatalog/quitSmoking`` does.
    public static var clean: Measure {
        Measure(kind: .count, dailyTarget: .zero)
    }
}
