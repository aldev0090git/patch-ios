import Foundation
import Testing
@testable import PatchCore

@Suite("Manual entry amounts")
struct ManualAmountsTests {
    @Test("A twenty-minute goal offers every minute")
    func readingByTheMinute() {
        let options = ManualAmounts.options(for: .minutes(20))

        #expect(options.first == 60)
        #expect(options.last == 1200)
        #expect(options.count == 20)
    }

    @Test("A long goal steps more coarsely rather than growing endlessly")
    func longGoalsUseACoarserStep() {
        let options = ManualAmounts.options(for: .minutes(120))

        #expect(options.count <= 40)
        #expect(options.last == 7200)
        #expect(options.first == 300) // 5-minute steps
    }

    @Test("Push-ups are offered one at a time")
    func pushUpsByOne() {
        let expected: [Decimal] = (1...20).map { Decimal($0) }
        #expect(ManualAmounts.options(for: .times(20)) == expected)
    }

    @Test("Water steps in 50 ml and reaches the full target")
    func waterStepsInFifties() {
        let options = ManualAmounts.options(for: .millilitres(2000))

        #expect(options.first == 50)
        #expect(options.last == 2000)
        #expect(options.count == 40)
    }

    @Test("Ten thousand steps stay within a spinnable list")
    func stepsStayManageable() {
        let options = ManualAmounts.options(for: .steps(10_000))

        #expect(options.count <= 40)
        #expect(options.last == 10_000)
    }

    @Test("The full target is always reachable, even on an awkward step")
    func targetIsAlwaysIncluded() {
        // 7 is not a whole number of any candidate step above 1.
        let options = ManualAmounts.options(for: .times(7))
        #expect(options.last == 7)

        let awkward = ManualAmounts.options(for: .millilitres(1730))
        #expect(awkward.last == 1730)
    }

    @Test("Every list ascends and holds no duplicates")
    func listsAreWellFormed() {
        let measures: [Measure] = [
            .minutes(5), .minutes(45), .times(3), .times(250),
            .millilitres(750), .steps(6000), .money(37, quickAdd: 10)
        ]

        for measure in measures {
            let options = ManualAmounts.options(for: measure)
            #expect(!options.isEmpty)
            #expect(options == options.sorted())
            #expect(Set(options).count == options.count)
            #expect(options.last == measure.dailyTarget)
        }
    }

    @Test("A goal with no target has nothing to offer")
    func zeroTargetHasNoOptions() {
        #expect(ManualAmounts.options(for: .clean).isEmpty)
    }
}
