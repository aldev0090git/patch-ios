import Foundation
import Testing
@testable import PatchCore

@Suite("Long-run targets")
struct CumulativeProgressTests {
    private let calendar = fixedCalendar()

    private func goal(target: Decimal? = 100_000, deadline: Date? = nil) -> Goal {
        Goal(
            title: "Save",
            measure: .money(5000),
            schedule: .daysOfMonth([1]),
            cumulativeTarget: target,
            cumulativeDeadline: deadline,
            createdAt: day(2026, 1, 1)
        )
    }

    private func entries(_ goal: Goal, amounts: [(Decimal, Date)]) -> [Entry] {
        amounts.map { Entry(goalID: goal.id, amount: $0.0, loggedAt: $0.1) }
    }

    @Test("A goal without a long-run target reports none")
    func noTargetNoProgress() {
        let progress = ProgressCalculator(calendar: calendar)
            .cumulativeProgress(for: goal(target: nil), entries: [], asOf: day(2026, 3, 1))
        #expect(progress == nil)
    }

    @Test("Everything logged counts toward it, not just scheduled days")
    func totalsAccumulate() {
        let goal = goal()
        let logged = entries(goal, amounts: [(5000, day(2026, 1, 1)), (5000, day(2026, 2, 1))])
        let progress = ProgressCalculator(calendar: calendar)
            .cumulativeProgress(for: goal, entries: logged, asOf: day(2026, 2, 15))

        #expect(progress?.total == 10_000)
        #expect(progress?.remaining == 90_000)
        #expect(progress?.isReached == false)
    }

    @Test("Beating the target does not push the bar past full")
    func fractionIsClamped() {
        let goal = goal(target: 1000)
        let logged = entries(goal, amounts: [(5000, day(2026, 1, 1))])
        let progress = ProgressCalculator(calendar: calendar)
            .cumulativeProgress(for: goal, entries: logged, asOf: day(2026, 2, 1))

        #expect(progress?.isReached == true)
        #expect(progress?.fraction == 1)
        #expect(progress?.remaining == 0)
    }

    @Test("Days remaining counts down to the deadline and past it")
    func daysRemaining() {
        let goal = goal(deadline: day(2026, 3, 10))
        let calculator = ProgressCalculator(calendar: calendar)

        #expect(calculator.cumulativeProgress(for: goal, entries: [], asOf: day(2026, 3, 1))?.daysRemaining == 9)
        #expect(calculator.cumulativeProgress(for: goal, entries: [], asOf: day(2026, 3, 10))?.daysRemaining == 0)
        #expect(calculator.cumulativeProgress(for: goal, entries: [], asOf: day(2026, 3, 12))?.daysRemaining == -2)
    }

    @Test("A deadline that has passed without the target is overdue")
    func overdueWhenMissed() {
        let goal = goal(deadline: day(2026, 3, 1))
        let progress = ProgressCalculator(calendar: calendar)
            .cumulativeProgress(for: goal, entries: [], asOf: day(2026, 3, 5))

        #expect(progress?.isOverdue == true)
    }

    @Test("Reaching the target early and letting the date pass is not a failure")
    func reachedEarlyIsNotOverdue() {
        let goal = goal(target: 1000, deadline: day(2026, 3, 1))
        let logged = entries(goal, amounts: [(1000, day(2026, 1, 5))])
        let progress = ProgressCalculator(calendar: calendar)
            .cumulativeProgress(for: goal, entries: logged, asOf: day(2026, 6, 1))

        #expect(progress?.isReached == true)
        #expect(progress?.isOverdue == false)
    }

    @Test("The pace needed is what is left spread over the days left")
    func requiredPerDay() {
        let goal = goal(target: 1000, deadline: day(2026, 1, 11))
        let logged = entries(goal, amounts: [(500, day(2026, 1, 1))])
        let progress = ProgressCalculator(calendar: calendar)
            .cumulativeProgress(for: goal, entries: logged, asOf: day(2026, 1, 1))

        #expect(progress?.requiredPerRemainingDay == 50)
    }

    @Test("No pace is offered once there is nothing left to pace")
    func noPaceWhenDoneOrOutOfTime() {
        let calculator = ProgressCalculator(calendar: calendar)

        // Target already met.
        let met = goal(target: 100, deadline: day(2026, 2, 1))
        let metEntries = entries(met, amounts: [(100, day(2026, 1, 1))])
        #expect(calculator.cumulativeProgress(for: met, entries: metEntries, asOf: day(2026, 1, 2))?
            .requiredPerRemainingDay == nil)

        // Deadline gone: no per-day number rescues a date already passed.
        let late = goal(target: 100, deadline: day(2026, 1, 1))
        #expect(calculator.cumulativeProgress(for: late, entries: [], asOf: day(2026, 2, 1))?
            .requiredPerRemainingDay == nil)

        // No deadline at all.
        #expect(calculator.cumulativeProgress(for: goal(target: 100), entries: [], asOf: day(2026, 1, 1))?
            .requiredPerRemainingDay == nil)
    }

    @Test("A goal with no deadline still reports progress, just no countdown")
    func noDeadlineStillTracks() {
        let goal = goal()
        let logged = entries(goal, amounts: [(25_000, day(2026, 1, 1))])
        let progress = ProgressCalculator(calendar: calendar)
            .cumulativeProgress(for: goal, entries: logged, asOf: day(2026, 2, 1))

        #expect(progress?.daysRemaining == nil)
        #expect(progress?.isOverdue == false)
        #expect(progress?.fraction == 0.25)
    }
}
