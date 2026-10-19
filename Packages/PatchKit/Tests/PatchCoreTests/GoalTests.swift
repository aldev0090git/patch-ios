import Foundation
import Testing
@testable import PatchCore

@Suite("Logging style")
struct LoggingStyleTests {
    @Test("A goal you accumulate through the day is incremental")
    func readingIsIncremental() {
        let goal = Goal(title: "Read", measure: .minutes(20))
        #expect(goal.loggingStyle == .incremental)
    }

    @Test("A once-a-day goal is a single yes or no")
    func gymIsSingle() {
        let goal = GoalTemplateCatalog.gym.makeGoal(title: "Gym")
        #expect(goal.loggingStyle == .single)
    }

    @Test("Staying smoke-free is confirmed once a day, like any other single goal")
    func quitSmokingIsSingle() {
        let goal = GoalTemplateCatalog.quitSmoking.makeGoal(title: "Don't smoke")
        #expect(goal.loggingStyle == .single)
        #expect(goal.direction == .atLeast)
    }

    @Test("An allowance you can spend down is still incremental")
    func allowanceIsIncremental() {
        // "At most two coffees" has room to use, unlike "at most zero".
        let goal = Goal(title: "Coffee", measure: .times(2), direction: .atMost)
        #expect(goal.loggingStyle == .incremental)
    }

    @Test("A multi-rep goal is incremental even though it is a count")
    func pushUpsAreIncremental() {
        let goal = Goal(title: "Push-ups", measure: .times(20))
        #expect(goal.loggingStyle == .incremental)
    }
}

@Suite("Template titles")
struct TemplateTitleTests {
    @Test("A goal built from a template carries the template's key")
    func templateGoalKeepsKey() {
        let goal = GoalTemplateCatalog.read.makeGoal(title: "Read")
        #expect(goal.titleKey == "template.read")
        #expect(goal.title == "Read")
    }

    @Test("Every template's key is distinct, so two goals can't resolve alike")
    func templateKeysAreUnique() {
        let keys = GoalTemplateCatalog.all.map(\.titleKey)
        #expect(Set(keys).count == keys.count)
    }

    @Test("A goal the user names carries no key")
    func userGoalHasNoKey() {
        let goal = Goal(title: "Walk the dog", measure: .times(1))
        #expect(goal.titleKey == nil)
    }
}

@Suite("Reminders")
struct ReminderTests {
    @Test("A reminder is a time of day, not an instant")
    func componentsCarryOnlyTheTime() {
        let reminder = Reminder(hour: 8, minute: 30)
        #expect(reminder.components.hour == 8)
        #expect(reminder.components.minute == 30)
        #expect(reminder.components.day == nil)
        #expect(reminder.components.year == nil)
    }

    @Test("An impossible time is clamped rather than refused")
    func outOfRangeIsClamped() {
        // A corrupt stored value must not cost the user their reminders.
        #expect(Reminder(hour: 99, minute: 99) == Reminder(hour: 23, minute: 59))
        #expect(Reminder(hour: -4, minute: -1) == Reminder(hour: 0, minute: 0))
    }

    @Test("Check-ins sort down the day, not by the order they were added")
    func ordersByClockTime() {
        let times = [Reminder(hour: 20, minute: 0), Reminder(hour: 8, minute: 45),
                     Reminder(hour: 8, minute: 5)]
        #expect(times.sorted() == [Reminder(hour: 8, minute: 5),
                                   Reminder(hour: 8, minute: 45),
                                   Reminder(hour: 20, minute: 0)])
    }
}

@Suite("Changing a target")
struct TargetHistoryTests {
    private let calendar = fixedCalendar()

    private func goal() -> Goal {
        Goal(
            title: "Read",
            measure: .minutes(20),
            createdAt: day(2026, 1, 1)
        )
    }

    @Test("A goal whose target never changed answers the same for every day")
    func noHistoryMeansOneTarget() {
        let goal = goal()
        #expect(goal.dailyTarget(on: day(2026, 1, 1), calendar: calendar) == 1200)
        #expect(goal.dailyTarget(on: day(2026, 6, 1), calendar: calendar) == 1200)
    }

    @Test("Raising a target leaves the days before it alone")
    func raisingDoesNotRewriteThePast() {
        // The whole point: a month of finished 20-minute days must not become
        // a month of failures because you later asked for an hour.
        let raised = goal().withTarget(3600, changedOn: day(2026, 2, 1), calendar: calendar)

        #expect(raised.dailyTarget(on: day(2026, 1, 15), calendar: calendar) == 1200)
        #expect(raised.dailyTarget(on: day(2026, 2, 1), calendar: calendar) == 3600)
        #expect(raised.dailyTarget(on: day(2026, 3, 1), calendar: calendar) == 3600)
    }

    @Test("The day of the change already uses the new target")
    func changeAppliesFromItsOwnDay() {
        let raised = goal().withTarget(3600, changedOn: day(2026, 2, 1), calendar: calendar)
        #expect(raised.dailyTarget(on: day(2026, 1, 31), calendar: calendar) == 1200)
        #expect(raised.dailyTarget(on: day(2026, 2, 1), calendar: calendar) == 3600)
    }

    @Test("The current target is the latest one")
    func measureHoldsTheCurrentTarget() {
        let raised = goal().withTarget(3600, changedOn: day(2026, 2, 1), calendar: calendar)
        #expect(raised.measure.dailyTarget == 3600)
        #expect(raised.measure.kind == .duration)
    }

    @Test("Several changes each apply from their own day")
    func historyStacks() {
        let goal = goal()
            .withTarget(3600, changedOn: day(2026, 2, 1), calendar: calendar)
            .withTarget(1800, changedOn: day(2026, 3, 1), calendar: calendar)

        #expect(goal.dailyTarget(on: day(2026, 1, 10), calendar: calendar) == 1200)
        #expect(goal.dailyTarget(on: day(2026, 2, 10), calendar: calendar) == 3600)
        #expect(goal.dailyTarget(on: day(2026, 3, 10), calendar: calendar) == 1800)
    }

    @Test("Changing your mind twice in one day leaves one entry")
    func sameDayChangesCollapse() {
        let goal = goal()
            .withTarget(3600, changedOn: day(2026, 2, 1), calendar: calendar)
            .withTarget(2400, changedOn: day(2026, 2, 1), calendar: calendar)

        #expect(goal.targetHistory.count == 2)  // the original, and today's
        #expect(goal.dailyTarget(on: day(2026, 2, 1), calendar: calendar) == 2400)
        #expect(goal.dailyTarget(on: day(2026, 1, 1), calendar: calendar) == 1200)
    }

    @Test("Setting the same target again records nothing")
    func noChangeNoHistory() {
        let unchanged = goal().withTarget(1200, changedOn: day(2026, 2, 1), calendar: calendar)
        #expect(unchanged.targetHistory.isEmpty)
    }

    @Test("A day before the goal existed falls back rather than returning zero")
    func daysBeforeTheFirstEntry() {
        let raised = goal().withTarget(3600, changedOn: day(2026, 2, 1), calendar: calendar)
        #expect(raised.dailyTarget(on: day(2025, 12, 1), calendar: calendar) == 1200)
    }

    @Test("Progress judges each day by the target of that day")
    func progressUsesTheTargetOfTheDay() {
        let raised = goal().withTarget(3600, changedOn: day(2026, 2, 1), calendar: calendar)
        let entries = [
            Entry(goalID: raised.id, amount: 1200, loggedAt: day(2026, 1, 15)),
            Entry(goalID: raised.id, amount: 1200, loggedAt: day(2026, 2, 15))
        ]
        let calculator = ProgressCalculator(calendar: calendar)

        // Twenty minutes was enough in January and is not enough in February.
        #expect(calculator.progress(for: raised, entries: entries, on: day(2026, 1, 15)).isAchieved)
        #expect(!calculator.progress(for: raised, entries: entries, on: day(2026, 2, 15)).isAchieved)
    }

    @Test("A streak built under the old target survives the new one")
    func streaksSurviveARaise() {
        var goal = goal()
        let days = (1...5).map { day(2026, 1, $0) }
        let entries = days.map { Entry(goalID: goal.id, amount: 1200, loggedAt: $0) }
        goal = goal.withTarget(3600, changedOn: day(2026, 1, 6), calendar: calendar)

        let streak = StreakCalculator(calendar: calendar)
            .longestStreak(for: goal, entries: entries, asOf: day(2026, 1, 6))

        #expect(streak == 5)
    }
}

@Suite("Dates of the month")
struct MonthlyScheduleTests {
    private let calendar = fixedCalendar()

    @Test("A goal on the 1st runs on the 1st and no other day")
    func singleDate() {
        let schedule = Schedule.daysOfMonth([1])
        #expect(schedule.isScheduled(on: day(2026, 3, 1), calendar: calendar))
        #expect(!schedule.isScheduled(on: day(2026, 3, 2), calendar: calendar))
        #expect(schedule.isScheduled(on: day(2026, 4, 1), calendar: calendar))
    }

    @Test("Twice a month runs on both dates")
    func twiceAMonth() {
        // The salary case: paid on the 1st and the 15th.
        let schedule = Schedule.daysOfMonth([1, 15])
        #expect(schedule.isScheduled(on: day(2026, 3, 1), calendar: calendar))
        #expect(schedule.isScheduled(on: day(2026, 3, 15), calendar: calendar))
        #expect(!schedule.isScheduled(on: day(2026, 3, 16), calendar: calendar))
    }

    @Test("The 31st still happens in a month that has no 31st")
    func shortMonthsFallBackToTheirLastDay() {
        // Someone paid on the 31st is still paid in February. Skipping it
        // would be invisible — a skipped day does not even break a streak.
        let schedule = Schedule.daysOfMonth([31])
        #expect(schedule.isScheduled(on: day(2026, 2, 28), calendar: calendar))
        #expect(!schedule.isScheduled(on: day(2026, 2, 27), calendar: calendar))
        #expect(schedule.isScheduled(on: day(2026, 1, 31), calendar: calendar))
        #expect(!schedule.isScheduled(on: day(2026, 1, 30), calendar: calendar))
    }

    @Test("A leap February puts the 30th on the 29th")
    func leapYear() {
        let schedule = Schedule.daysOfMonth([30])
        #expect(schedule.isScheduled(on: day(2028, 2, 29), calendar: calendar))
        #expect(!schedule.isScheduled(on: day(2028, 2, 28), calendar: calendar))
    }

    @Test("A date that exists is not also pulled onto the last day")
    func noDoubleCounting() {
        // The 15th must not fire twice in a month that also ends on a day the
        // set happens to contain.
        let schedule = Schedule.daysOfMonth([15])
        #expect(!schedule.isScheduled(on: day(2026, 3, 31), calendar: calendar))
    }

    @Test("An empty set never runs, rather than running every day")
    func emptyNeverRuns() {
        let schedule = Schedule.daysOfMonth([])
        for date in 1...28 {
            #expect(!schedule.isScheduled(on: day(2026, 3, date), calendar: calendar))
        }
    }

    @Test("Unscheduled dates are skipped, not missed")
    func unscheduledDaysAreNotFailures() {
        let goal = Goal(
            title: "Save",
            measure: .money(5000),
            schedule: .daysOfMonth([1]),
            createdAt: day(2026, 1, 1)
        )
        let progress = ProgressCalculator(calendar: calendar)
            .progress(for: goal, entries: [], on: day(2026, 3, 2))

        #expect(!progress.isScheduled)
        #expect(!progress.isAchieved)
    }
}
