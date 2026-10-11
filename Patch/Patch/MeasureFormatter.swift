import Foundation
import PatchCore

/// Turns canonical amounts into short display strings.
///
/// Lives in the app, not in PatchCore: how a number is written is a
/// presentation concern that changes per language. The domain only ever deals
/// in seconds, millilitres and metres.
///
/// Built on Foundation's own measurement and duration formatting rather than
/// hand-assembled strings. Writing `"\(value) min"` would need "хв" in
/// Ukrainian and "мин" in Russian, and would still get plural forms wrong in
/// both — Foundation already knows all of that.
///
/// `nonisolated` because this is pure computation over value types. The app
/// target defaults to `MainActor` isolation, which would otherwise make these
/// callable only from the main actor and stop tests from using them at all.
nonisolated enum MeasureFormatter {
    /// Preferred over the `kind:` form wherever a ``Measure`` is in hand: it
    /// carries the currency with it, so a money amount cannot lose its symbol
    /// by a caller forgetting to pass one.
    static func short(
        _ amount: Decimal,
        measure: Measure,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        short(amount, kind: measure.kind, currencyCode: measure.currencyCode, locale: locale)
    }

    /// - Parameters:
    ///   - currencyCode: only used by ``MeasureKind/currency``; nil falls back
    ///     to the reader's own currency.
    ///   - locale: injectable so tests can pin a language and not depend on
    ///     whatever the machine running them is set to.
    static func short(
        _ amount: Decimal,
        kind: MeasureKind,
        currencyCode: String? = nil,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        switch kind {
        case .duration:
            duration(seconds: double(amount), locale: locale)
        case .count:
            number(amount, locale: locale)
        case .currency:
            money(amount, code: currencyCode, locale: locale)
        case .volume:
            volume(millilitres: double(amount), locale: locale)
        case .distance:
            distance(metres: double(amount), locale: locale)
        }
    }

    /// Formatted with its own symbol, because "100" says nothing about
    /// whether it is dollars, euros or hryvnia. Falls back to the reader's own
    /// currency for a goal created before the question was asked.
    private static func money(_ amount: Decimal, code: String?, locale: Locale) -> String {
        let resolved = code ?? locale.currency?.identifier ?? "USD"
        return amount.formatted(
            .currency(code: resolved)
                // Whole units: a savings goal is "2 000 ₴", never "2 000,00 ₴".
                .precision(.fractionLength(0))
                .locale(locale)
        )
    }

    private static func duration(seconds: Double, locale: Locale) -> String {
        // Hours and minutes only: nobody logs reading in seconds, and allowing
        // them turns "1 h" into "1 h 0 min 0 s".
        Duration.seconds(seconds).formatted(
            .units(allowed: [.hours, .minutes], width: .abbreviated, zeroValueUnits: .hide)
                .locale(locale)
        )
    }

    private static func volume(millilitres: Double, locale: Locale) -> String {
        if millilitres >= 1000 {
            return measurement(millilitres / 1000, unit: UnitVolume.liters, locale: locale)
        }
        return measurement(millilitres, unit: UnitVolume.milliliters, locale: locale)
    }

    private static func distance(metres: Double, locale: Locale) -> String {
        if metres >= 1000 {
            return measurement(metres / 1000, unit: UnitLength.kilometers, locale: locale)
        }
        return measurement(metres, unit: UnitLength.meters, locale: locale)
    }

    /// Up to two decimals, trailing zeros dropped.
    ///
    /// One decimal is not enough: a water picker stepping in 50 ml rendered
    /// 1850, 1900 and 1950 all as "1.9 L", so three rows of the wheel were
    /// indistinguishable.
    private static func measurement<UnitType: Dimension>(
        _ value: Double,
        unit: UnitType,
        locale: Locale
    ) -> String {
        Measurement(value: value, unit: unit).formatted(
            .measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0...2))
            )
            .locale(locale)
        )
    }

    private static func number(_ amount: Decimal, locale: Locale) -> String {
        amount.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }

    private static func double(_ amount: Decimal) -> Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
}
