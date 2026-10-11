import Foundation
import PatchCore
import Testing
@testable import Patch

@Suite("Money goals")
struct CurrencyTests {
    @Test("An amount carries its currency, not a bare number")
    func amountsShowTheirCurrency() {
        let euros = MeasureFormatter.short(
            2000,
            measure: .money(2000, currencyCode: "EUR"),
            locale: Locale(identifier: "en_GB")
        )
        #expect(euros.contains("€"))
        #expect(euros.contains("2"))
    }

    @Test("The same number in different currencies formats differently")
    func currenciesAreDistinguishable() {
        // "100" alone is meaningless — the whole reason the code exists.
        let locale = Locale(identifier: "en_GB")
        let dollars = MeasureFormatter.short(100, measure: .money(100, currencyCode: "USD"), locale: locale)
        let hryvnia = MeasureFormatter.short(100, measure: .money(100, currencyCode: "UAH"), locale: locale)

        #expect(dollars != hryvnia)
    }

    @Test("Whole units only — a savings target is not written with pennies")
    func noFractionDigits() {
        let text = MeasureFormatter.short(
            2000,
            measure: .money(2000, currencyCode: "USD"),
            locale: Locale(identifier: "en_US")
        )
        #expect(!text.contains(".00"))
    }

    @Test("A goal with no currency falls back to the reader's own")
    func fallsBackToTheLocale() {
        let text = MeasureFormatter.short(
            100,
            measure: .money(100),
            locale: Locale(identifier: "de_DE")
        )
        #expect(text.contains("€"))
    }

    @Test("Only money carries a currency code")
    func otherKindsHaveNoCurrency() {
        // Otherwise two identical reading goals could differ by a field
        // neither of them uses.
        let reading = Measure(kind: .duration, dailyTarget: 1200, currencyCode: "USD")
        #expect(reading.currencyCode == nil)
    }

    @Test("Every offered currency has a label and a symbol")
    func optionsAreUsable() {
        let locale = Locale(identifier: "en_GB")
        for code in CurrencyOptions.all.prefix(40) {
            #expect(CurrencyOptions.label(for: code, locale: locale).contains(code))
            #expect(!CurrencyOptions.symbol(for: code, locale: locale).isEmpty)
        }
    }

    @Test("The reader's own currency is offered first")
    func ownCurrencyLeadsTheList() {
        #expect(CurrencyOptions.all.first == CurrencyOptions.deviceDefault)
        #expect(Set(CurrencyOptions.all).count == CurrencyOptions.all.count)
    }

    @Test("A symbol never comes back as digits")
    func symbolsAreNotNumbers() {
        let symbol = CurrencyOptions.symbol(for: "UAH", locale: Locale(identifier: "uk_UA"))
        #expect(!symbol.contains("0"))
        #expect(!symbol.isEmpty)
    }
}
