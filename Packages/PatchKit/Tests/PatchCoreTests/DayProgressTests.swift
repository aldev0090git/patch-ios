import Foundation
import Testing
@testable import PatchCore

@Suite("Daily progress")
struct DayProgressTests {
    let calculator = ProgressCalculator(calendar: fixedCalendar())

    @Test("Reading split across the day adds up to a finished target")
    func readingSplitsAcrossTheDay() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 5))
        let entries = [
            Entry(goalID: goal.id, amount: 600, loggedAt: day(2026, 1, 5, hour: 8)),
            Entry(goalID: goal.id, amount: 600, loggedAt: day(2026, 1, 5, hour: 21))
        ]

        let progress = calculator.progress(for: goal, entries: entries, on: day(2026, 1, 5))

        #expect(progress.total == 1200)
        #expect(progress.isAchieved)
        #expect(progress.fraction == 1)
        #expect(progress.remaining == 0)
    }

    @Test("Half the target reports half the progress")
    func partialProgress() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 5))
        let entries = [Entry(goalID: goal.id, amount: 600, loggedAt: day(2026, 1, 5))]

        let progress = calculator.progress(for: goal, entries: entries, on: day(2026, 1, 5))

        #expect(!progress.isAchieved)
        #expect(abs(progress.fraction - 0.5) < 0.0001)
        #expect(progress.remaining == 600)
    }

    @Test("Overshooting the target does not push the ring past full")
    func fractionIsClamped() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 5))
        let entries = [Entry(goalID: goal.id, amount: 2400, loggedAt: day(2026, 1, 5))]

        let progress = calculator.progress(for: goal, entries: entries, on: day(2026, 1, 5))

        #expect(progress.isAchieved)
        #expect(progress.fraction == 1)
    }

    @Test("Water accumulates one glass at a time")
    func waterAccumulates() {
        let goal = Goal(title: "Water", measure: .millilitres(2000), createdAt: day(2026, 1, 5))
        let entries = (0..<8).map { index in
            Entry(goalID: goal.id, amount: 250, loggedAt: day(2026, 1, 5, hour: 8 + index))
        }

        let progress = calculator.progress(for: goal, entries: entries, on: day(2026, 1, 5))

        #expect(progress.total == 2000)
        #expect(progress.isAchieved)
    }

    @Test("A negative entry corrects a mistake rather than rewriting history")
    func correctionsSubtract() {
        let goal = Goal(title: "Push-ups", measure: .times(100), createdAt: day(2026, 1, 5))
        let entries = [
            Entry(goalID: goal.id, amount: 100, loggedAt: day(2026, 1, 5, hour: 9)),
            Entry(goalID: goal.id, amount: -40, loggedAt: day(2026, 1, 5, hour: 10))
        ]

        let progress = calculator.progress(for: goal, entries: entries, on: day(2026, 1, 5))

        #expect(progress.total == 60)
        #expect(!progress.isAchieved)
    }

    @Test("Entries from another goal never leak into this one's total")
    func entriesAreIsolatedPerGoal() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 5))
        let other = Goal(title: "Water", measure: .millilitres(2000), createdAt: day(2026, 1, 5))
        let entries = [
            Entry(goalID: goal.id, amount: 600, loggedAt: day(2026, 1, 5)),
            Entry(goalID: other.id, amount: 9999, loggedAt: day(2026, 1, 5))
        ]

        let progress = calculator.progress(for: goal, entries: entries, on: day(2026, 1, 5))

        #expect(progress.total == 600)
    }
}

@Suite("Goals you are trying to avoid")
struct AtMostTests {
    let calculator = ProgressCalculator(calendar: fixedCalendar())

    @Test("A clean day needs no entries at all")
    func cleanDayNeedsNoEntries() {
        let goal = Goal(title: "Don't smoke", measure: .clean,
                        direction: .atMost, createdAt: day(2026, 1, 5))

        let progress = calculator.progress(for: goal, entries: [], on: day(2026, 1, 5))

        #expect(progress.total == 0)
        #expect(progress.isAchieved)
        #expect(progress.fraction == 1)
    }

    @Test("A single slip fails the day")
    func oneSlipFailsTheDay() {
        let goal = Goal(title: "Don't smoke", measure: .clean,
                        direction: .atMost, createdAt: day(2026, 1, 5))
        let entries = [Entry(goalID: goal.id, amount: 1, loggedAt: day(2026, 1, 5))]

        let progress = calculator.progress(for: goal, entries: entries, on: day(2026, 1, 5))

        #expect(!progress.isAchieved)
        #expect(progress.fraction == 0)
    }

    @Test("An allowance holds while you stay inside it")
    func allowanceHolds() {
        let goal = Goal(title: "Coffee", measure: .times(2),
                        direction: .atMost, createdAt: day(2026, 1, 5))
        let entries = [
            Entry(goalID: goal.id, amount: 1, loggedAt: day(2026, 1, 5, hour: 9)),
            Entry(goalID: goal.id, amount: 1, loggedAt: day(2026, 1, 5, hour: 14))
        ]

        let progress = calculator.progress(for: goal, entries: entries, on: day(2026, 1, 5))

        #expect(progress.isAchieved)
        #expect(progress.budgetUsed == 1.0)
    }

    @Test("Going over the allowance reports how far over")
    func allowanceExceeded() {
        let goal = Goal(title: "Coffee", measure: .times(2),
                        direction: .atMost, createdAt: day(2026, 1, 5))
        let entries = (0..<3).map {
            Entry(goalID: goal.id, amount: 1, loggedAt: day(2026, 1, 5, hour: 9 + $0))
        }

        let progress = calculator.progress(for: goal, entries: entries, on: day(2026, 1, 5))

        #expect(!progress.isAchieved)
        #expect(progress.budgetUsed == 1.5)
    }

    @Test("A zero-target goal has no meaningful budget to report")
    func zeroTargetHasNoBudget() {
        let goal = Goal(title: "Don't smoke", measure: .clean,
                        direction: .atMost, createdAt: day(2026, 1, 5))

        let progress = calculator.progress(for: goal, entries: [], on: day(2026, 1, 5))

        #expect(progress.budgetUsed == nil)
    }
}

@Suite("Failed days")
struct FailedDayTests {
    let calculator = ProgressCalculator(calendar: fixedCalendar())

    @Test("Going over a limit fails the day outright")
    func overLimitIsFailed() {
        let goal = Goal(title: "Don't smoke", measure: .clean,
                        direction: .atMost, createdAt: day(2026, 1, 5))
        let slip = [Entry(goalID: goal.id, amount: 1, loggedAt: day(2026, 1, 5))]

        let progress = calculator.progress(for: goal, entries: slip, on: day(2026, 1, 5))

        #expect(progress.isFailed)
        #expect(!progress.isAchieved)
    }

    @Test("A clean day has not failed")
    func cleanDayIsNotFailed() {
        let goal = Goal(title: "Don't smoke", measure: .clean,
                        direction: .atMost, createdAt: day(2026, 1, 5))

        let progress = calculator.progress(for: goal, entries: [], on: day(2026, 1, 5))

        #expect(!progress.isFailed)
    }

    @Test("An unfinished goal is in progress, not failed")
    func unfinishedIsNotFailed() {
        // Half a reading goal at lunchtime is not a failure.
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 5))
        let entries = [Entry(goalID: goal.id, amount: 600, loggedAt: day(2026, 1, 5))]

        let progress = calculator.progress(for: goal, entries: entries, on: day(2026, 1, 5))

        #expect(!progress.isFailed)
        #expect(!progress.isAchieved)
    }

    @Test("An untouched goal is in progress, not failed")
    func emptyDayIsNotFailed() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 5))

        let progress = calculator.progress(for: goal, entries: [], on: day(2026, 1, 5))

        #expect(!progress.isFailed)
    }
}
