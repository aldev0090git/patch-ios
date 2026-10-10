import Foundation
import PatchCore

/// Turns canonical amounts into short display strings.
///
/// Lives in the app, not in PatchCore: how a number is written is a
/// presentation concern, and it changes per language. The domain only ever
/// deals in seconds, millilitres and metres.
///
/// `nonisolated` because this is pure computation over value types. The app
/// target defaults to `MainActor` isolation, which would otherwise make these
/// callable only from the main actor and stop tests from using them at all.
nonisolated enum MeasureFormatter {
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
        case (let hours, let minutes): return "\(hours) h \(minutes) min"
        }
    }

    private static func whole(_ amount: Decimal) -> String {
        var value = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).stringValue
    }

    /// Up to two decimals, with trailing zeros dropped.
    ///
    /// One decimal is not enough: a water picker stepping in 50 ml rendered
    /// 1850, 1900 and 1950 all as "1.9 L", so three different rows of the
    /// wheel were indistinguishable.
    private static func trimmed(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        var text = String(format: "%.2f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}
