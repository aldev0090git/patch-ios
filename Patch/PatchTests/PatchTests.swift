import Foundation
import PatchCore
import Testing
@testable import Patch

@Suite("Measure formatting")
struct MeasureFormatterTests {
    @Test("Minutes under an hour read as minutes")
    func minutes() {
        #expect(MeasureFormatter.short(1200, kind: .duration) == "20 min")
        #expect(MeasureFormatter.short(300, kind: .duration) == "5 min")
    }

    @Test("A whole number of hours drops the minutes")
    func wholeHours() {
        #expect(MeasureFormatter.short(3600, kind: .duration) == "1 h")
        #expect(MeasureFormatter.short(7200, kind: .duration) == "2 h")
    }

    @Test("Hours and minutes together keep both units")
    func hoursAndMinutes() {
        // Regressed once: this rendered as "1 h 1", with the unit missing.
        #expect(MeasureFormatter.short(3660, kind: .duration) == "1 h 1 min")
        #expect(MeasureFormatter.short(5400, kind: .duration) == "1 h 30 min")
    }

    @Test("Volume switches to litres above a litre")
    func volume() {
        #expect(MeasureFormatter.short(250, kind: .volume) == "250 ml")
        #expect(MeasureFormatter.short(2000, kind: .volume) == "2 L")
        #expect(MeasureFormatter.short(1500, kind: .volume) == "1.5 L")
    }

    @Test("Distance switches to kilometres above a kilometre")
    func distance() {
        #expect(MeasureFormatter.short(500, kind: .distance) == "500 m")
        #expect(MeasureFormatter.short(5000, kind: .distance) == "5 km")
    }

    @Test("Counts and money render as plain whole numbers")
    func plainNumbers() {
        #expect(MeasureFormatter.short(20, kind: .count) == "20")
        #expect(MeasureFormatter.short(100, kind: .currency) == "100")
    }
}
