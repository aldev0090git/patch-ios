import Foundation
import PatchCore
import Testing
@testable import Patch

@Suite("Measure formatting")
struct MeasureFormatterTests {
    private let english = Locale(identifier: "en_US")

    private func short(_ amount: Decimal, _ kind: MeasureKind) -> String {
        MeasureFormatter.short(amount, kind: kind, locale: english)
    }

    @Test("Minutes under an hour read as minutes")
    func minutes() {
        #expect(short(1200, .duration) == "20 min")
        #expect(short(300, .duration) == "5 min")
        #expect(short(0, .duration) == "0 min")
    }

    @Test("A whole number of hours drops the minutes")
    func wholeHours() {
        #expect(short(3600, .duration) == "1 hr")
        #expect(short(7200, .duration) == "2 hr")
    }

    @Test("Hours and minutes together keep both units")
    func hoursAndMinutes() {
        // Regressed once when this was hand-assembled: 3660 rendered as "1 h 1",
        // with the unit missing entirely.
        #expect(short(3660, .duration) == "1 hr, 1 min")
        #expect(short(5400, .duration) == "1 hr, 30 min")
    }

    @Test("Volume switches to litres above a litre")
    func volume() {
        #expect(short(250, .volume) == "250 mL")
        #expect(short(2000, .volume) == "2 L")
        #expect(short(1500, .volume) == "1.5 L")
    }

    @Test("Nearby litre amounts stay distinguishable")
    func litresKeepEnoughPrecision() {
        // Regressed once: a picker stepping in 50 ml showed 1850, 1900 and
        // 1950 all as "1.9 L", making three wheel rows identical.
        let rendered = [Decimal(1850), 1900, 1950, 2000].map { short($0, .volume) }

        #expect(rendered == ["1.85 L", "1.9 L", "1.95 L", "2 L"])
        #expect(Set(rendered).count == rendered.count)
    }

    @Test("Distance switches to kilometres above a kilometre")
    func distance() {
        #expect(short(500, .distance) == "500 m")
        #expect(short(5000, .distance) == "5 km")
    }

    @Test("A count is a plain number")
    func plainNumbers() {
        #expect(short(20, .count) == "20")
    }

    @Test("Money is not a plain number — it carries its currency")
    func moneyIsNotPlain() {
        // This used to assert "100". A savings goal that does not say which
        // currency it is in is not a savings goal.
        #expect(short(100, .currency) != "100")
    }
}

@Suite("Measure formatting in other languages")
struct MeasureFormatterLocalisationTests {
    private let ukrainian = Locale(identifier: "uk_UA")
    private let russian = Locale(identifier: "ru_RU")

    @Test("Units are translated, not just the surrounding interface")
    func unitsAreTranslated() {
        #expect(MeasureFormatter.short(1200, kind: .duration, locale: ukrainian) == "20 хв")
        #expect(MeasureFormatter.short(1200, kind: .duration, locale: russian) == "20 мин")
        #expect(MeasureFormatter.short(3600, kind: .duration, locale: ukrainian) == "1 год")
        #expect(MeasureFormatter.short(250, kind: .volume, locale: ukrainian) == "250 мл")
        #expect(MeasureFormatter.short(5000, kind: .distance, locale: ukrainian) == "5 км")
    }

    @Test("Decimal separators follow the language")
    func decimalSeparatorsFollowTheLanguage() {
        // A hand-rolled formatter would have written "1.5 л" here, which is
        // wrong in both languages.
        #expect(MeasureFormatter.short(1500, kind: .volume, locale: ukrainian) == "1,5 л")
        #expect(MeasureFormatter.short(1500, kind: .volume, locale: russian) == "1,5 л")
    }
}
