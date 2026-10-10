import Foundation
import PatchCore

/// Turns canonical amounts into short display strings.
///
/// Lives in the app, not in PatchCore: how a number is written is a
/// presentation concern, and it changes per language. The domain only ever
/// deals in seconds, millilitres and metres.
enum MeasureFormatter {
    static func short(_ amount: Decimal, kind: MeasureKind) -> String {
        switch kind {
        case .duration:
            return duration(seconds: (amount as NSDecimalNumber).intValue)
        case .count:
            return whole(amount)
        case .volume:
            let millilitres = (amount as NSDecimalNumber).doubleValue
            return millilitres >= 1000
                ? "\(trimmed(millilitres / 1000)) L"
                : "\(whole(amount)) ml"
        case .distance:
            let metres = (amount as NSDecimalNumber).doubleValue
            return metres >= 1000
                ? "\(trimmed(metres / 1000)) km"
                : "\(whole(amount)) m"
        case .currency:
            return whole(amount)
        }
    }

    private static func duration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        switch (hours, minutes) {
        case (0, let minutes): return "\(minutes) min"
        case (let hours, 0): return "\(hours) h"
        case (let hours, let minutes): return "\(hours) h \(minutes)"
        }
    }

    private static func whole(_ amount: Decimal) -> String {
        var value = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).stringValue
    }

    private static func trimmed(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}
