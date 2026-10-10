import Foundation
import Testing
@testable import PatchCore

@Suite("Quick-add suggestions")
struct QuickAddTests {
    private func amounts(_ measure: Measure) -> [Decimal] {
        QuickAddSuggestions.options(for: measure).map(\.amount)
    }

    @Test("An hour of reading is offered in sittings, not in minutes")
    func readingAnHour() {
        // 15 min, 30 min, 1 h — in seconds.
        #expect(amounts(.minutes(60)) == [900, 1800, 3600])
    }

    @Test("A twenty-minute goal scales down to smaller bites")
    func readingTwentyMinutes() {
        // 5 min, 10 min, 20 min.
        #expect(amounts(.minutes(20)) == [300, 600, 1200])
    }

    @Test("Push-ups are offered in sets")
    func pushUps() {
        #expect(amounts(.times(100)) == [25, 50, 100])
    }

    @Test("Water is offered in glasses and bottles")
    func water() {
        #expect(amounts(.millilitres(2000)) == [500, 1000, 2000])
    }

    @Test("Steps are offered in thousands")
    func steps() {
        #expect(amounts(.steps(10_000)) == [2000, 5000, 10_000])
    }

    @Test("Money rounds to amounts people actually hand over")
    func money() {
        #expect(amounts(.money(100, quickAdd: 50)) == [25, 50, 100])
    }

    @Test("An abstinence goal offers only a single slip")
    func abstinenceOffersOneSlip() {
        let options = QuickAddSuggestions.options(for: .clean)
        #expect(options.map(\.amount) == [1])
    }

    @Test("Suggestions are always ascending, unique and at most three")
    func suggestionsAreWellFormed() {
        let measures: [Measure] = [
            .minutes(5), .minutes(90), .times(1), .times(7), .times(250),
            .millilitres(750), .steps(6000), .money(37, quickAdd: 10)
        ]

        for measure in measures {
            let values = amounts(measure)
            #expect(values.count <= 3)
            #expect(values == values.sorted())
            #expect(Set(values).count == values.count)
            #expect(values.allSatisfy { $0 > 0 })
        }
    }

    @Test("A tiny goal still produces at least one usable suggestion")
    func tinyGoalsDegradeGracefully() {
        #expect(!amounts(.times(1)).isEmpty)
        #expect(!amounts(.minutes(1)).isEmpty)
    }
}
