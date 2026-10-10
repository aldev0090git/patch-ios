import Foundation
import PatchCore

/// The unit people type a target in, and the conversion to canonical storage.
///
/// Nobody sets a reading goal in seconds, but seconds are what the domain
/// stores. This is the only place that knows the difference, so neither the
/// form nor the domain has to.
nonisolated enum MeasureInput {
    /// How many canonical units one entered unit is worth.
    private static func factor(for kind: MeasureKind) -> Decimal {
        switch kind {
        case .duration: 60      // entered in minutes, stored in seconds
        case .count: 1
        case .volume: 1         // entered in millilitres
        case .distance: 1       // entered in metres
        case .currency: 1
        }
    }

    static func toCanonical(_ entered: Decimal, kind: MeasureKind) -> Decimal {
        entered * factor(for: kind)
    }

    static func fromCanonical(_ stored: Decimal, kind: MeasureKind) -> Decimal {
        guard factor(for: kind) != 0 else { return stored }
        return stored / factor(for: kind)
    }

    /// Short unit label shown beside the field.
    static func unitLabel(for kind: MeasureKind) -> String {
        switch kind {
        case .duration: String(localized: "minutes")
        case .count: String(localized: "times")
        case .volume: String(localized: "ml")
        case .distance: String(localized: "metres")
        case .currency: String(localized: "per day")
        }
    }

    /// What the kind is called in the picker.
    static func kindLabel(for kind: MeasureKind) -> String {
        switch kind {
        case .duration: String(localized: "Time")
        case .count: String(localized: "Count")
        case .volume: String(localized: "Volume")
        case .distance: String(localized: "Distance")
        case .currency: String(localized: "Money")
        }
    }
}
