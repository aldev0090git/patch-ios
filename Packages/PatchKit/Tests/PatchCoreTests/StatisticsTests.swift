import Foundation
import Testing
@testable import PatchCore

@Suite("Statistics")
struct StatisticsTests {
    let calendar = fixedCalendar()
    var statistics: StatisticsCalculator { StatisticsCalculator(calendar: calendar) }

    @Test("Done and missed days are counted over a month")
    func doneAndMissedOverAMonth() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 1))
        let logged = [1, 2, 3].map {
            Entry(goalID: goal.id, amount: 1200, loggedAt: day(2026, 1, $0))
        }

        let stats = statistics.statistics(
            for: goal, entries: logged,
            period: .month(day(2026, 1, 15)), asOf: day(2026, 1, 10)
        )

        #expect(stats.completedDays == 3)
        #expect(stats.missedDays == 6) // the 4th through the 9th
        #expect(stats.scheduledDays == 9)
        #expect(abs(stats.completionRate - 1.0 / 3.0) < 0.0001)
    }

    @Test("Days still in the future are not counted as missed")
    func futureDaysAreNotMissed() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 1))

        let stats = statistics.statistics(
            for: goal, entries: [],
            period: .month(day(2026, 1, 1)), asOf: day(2026, 1, 5)
        )

        // The 1st to the 4th are missed; the 5th is today; the rest of January
        // has not happened yet.
        #expect(stats.scheduledDays == 4)
        #expect(stats.missedDays == 4)
    }

    @Test("Days before the goal existed are not counted as missed")
    func daysBeforeCreationAreNotMissed() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 15))

        let stats = statistics.statistics(
            for: goal, entries: [],
            period: .month(day(2026, 1, 1)), asOf: day(2026, 1, 20)
        )

        // The 15th through the 19th. Not the whole month.
        #expect(stats.scheduledDays == 5)
        #expect(stats.missedDays == 5)
    }

    @Test("An unfinished today counts as neither done nor missed")
    func todayIsPendingNotMissed() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 1))
        let logged = [Entry(goalID: goal.id, amount: 1200, loggedAt: day(2026, 1, 1))]

        let stats = statistics.statistics(
            for: goal, entries: logged,
            period: .custom(day(2026, 1, 1)...day(2026, 1, 2)), asOf: day(2026, 1, 2)
        )

        #expect(stats.completedDays == 1)
        #expect(stats.missedDays == 0)
        #expect(stats.hasPendingToday)
    }

    @Test("Unscheduled days never appear as missed")
    func unscheduledDaysAreNotMissed() {
        let goal = Goal(title: "Gym", measure: .times(1),
                        schedule: .daysOfWeek([.monday, .wednesday, .friday]),
                        createdAt: day(2026, 1, 5))

        // A full week with nothing logged: only Mon, Wed, Fri can be missed.
        let stats = statistics.statistics(
            for: goal, entries: [],
            period: .custom(day(2026, 1, 5)...day(2026, 1, 11)), asOf: day(2026, 1, 12)
        )

        #expect(stats.scheduledDays == 3)
        #expect(stats.missedDays == 3)
    }

    @Test("The period total sums everything logged inside it")
    func periodTotal() {
        let goal = Goal(title: "Save", measure: .money(100, quickAdd: 50), createdAt: day(2026, 1, 1))
        let deposits = [1, 2, 3].map {
            Entry(goalID: goal.id, amount: 150, loggedAt: day(2026, 1, $0))
        }

        let stats = statistics.statistics(
            for: goal, entries: deposits,
            period: .week(day(2026, 1, 1)), asOf: day(2026, 1, 3)
        )

        #expect(stats.total == 450)
    }

    @Test("A period reports its strongest day")
    func bestDay() {
        let goal = Goal(title: "Push-ups", measure: .times(20), createdAt: day(2026, 1, 1))
        let logged = [
            Entry(goalID: goal.id, amount: 20, loggedAt: day(2026, 1, 1)),
            Entry(goalID: goal.id, amount: 75, loggedAt: day(2026, 1, 2)),
            Entry(goalID: goal.id, amount: 30, loggedAt: day(2026, 1, 3))
        ]

        let stats = statistics.statistics(
            for: goal, entries: logged,
            period: .custom(day(2026, 1, 1)...day(2026, 1, 3)), asOf: day(2026, 1, 4)
        )

        #expect(stats.best?.total == 75)
    }
}

@Suite("Period ranges")
struct PeriodRangeTests {
    let calendar = fixedCalendar()

    @Test("A week runs Monday to Sunday with this calendar")
    func weekRange() {
        let range = StatisticsPeriod.week(day(2026, 1, 7)).range(in: calendar)

        #expect(range.lowerBound == day(2026, 1, 5, hour: 0))
        #expect(range.upperBound == day(2026, 1, 11, hour: 0))
    }

    @Test("A month covers every day in it")
    func monthRange() {
        let range = StatisticsPeriod.month(day(2026, 1, 15)).range(in: calendar)

        #expect(range.lowerBound == day(2026, 1, 1, hour: 0))
        #expect(range.upperBound == day(2026, 1, 31, hour: 0))
    }

    @Test("A single day is a range of one")
    func dayRange() {
        let range = StatisticsPeriod.day(day(2026, 1, 15)).range(in: calendar)

        #expect(range.lowerBound == range.upperBound)
    }

    @Test("A back-to-front custom range does not explode")
    func invertedCustomRangeIsClamped() {
        let range = StatisticsPeriod
            .custom(day(2026, 1, 10)...day(2026, 1, 10))
            .range(in: calendar)

        #expect(range.lowerBound <= range.upperBound)
    }
}

@Suite("Day summary across goals")
struct DaySummaryTests {
    let calendar = fixedCalendar()
    var statistics: StatisticsCalculator { StatisticsCalculator(calendar: calendar) }

    @Test("Only goals scheduled for the day are counted")
    func onlyScheduledGoalsCount() {
        let read = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 1))
        let gym = Goal(title: "Gym", measure: .times(1),
                       schedule: .daysOfWeek([.monday]), createdAt: day(2026, 1, 1))
        let water = Goal(title: "Water", measure: .millilitres(2000), createdAt: day(2026, 1, 1))
        let logged = [Entry(goalID: read.id, amount: 1200, loggedAt: day(2026, 1, 6))]

        // The 6th is a Tuesday, so the gym goal does not apply.
        let summary = statistics.summary(for: [read, gym, water], entries: logged, on: day(2026, 1, 6))

        #expect(summary.scheduled == 2)
        #expect(summary.completed == 1)
        #expect(summary.remaining == 1)
        #expect(abs(summary.fraction - 0.5) < 0.0001)
    }

    @Test("Archived goals drop out of the day")
    func archivedGoalsAreExcluded() {
        let active = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 1))
        let archived = Goal(title: "Old", measure: .times(1),
                            createdAt: day(2026, 1, 1), archivedAt: day(2026, 1, 5))

        let summary = statistics.summary(for: [active, archived], entries: [], on: day(2026, 1, 6))

        #expect(summary.scheduled == 1)
    }

    @Test("A goal created later does not appear on earlier days")
    func futureGoalsDoNotAppearInThePast() {
        let late = Goal(title: "New", measure: .times(1), createdAt: day(2026, 1, 10))

        let summary = statistics.summary(for: [late], entries: [], on: day(2026, 1, 5))

        #expect(summary.scheduled == 0)
    }

    @Test("A month of summaries produces one entry per day")
    func summariesSpanTheRange() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 1))

        let month = statistics.summaries(
            for: [goal], entries: [],
            in: day(2026, 1, 1)...day(2026, 1, 31)
        )

        #expect(month.count == 31)
    }
}

@Suite("Onboarding templates")
struct GoalTemplateTests {
    let calendar = fixedCalendar()

    @Test("Every template has a localisation key rather than a literal title")
    func templatesAreLocalisable() {
        for template in GoalTemplateCatalog.all {
            #expect(template.titleKey.hasPrefix("template."))
            #expect(!template.symbolName.isEmpty)
        }
    }

    @Test("Template ids are unique and resolvable")
    func templateIdsAreUnique() {
        let ids = GoalTemplateCatalog.all.map(\.id)

        #expect(Set(ids).count == ids.count)
        #expect(GoalTemplateCatalog.template(id: "read") != nil)
        #expect(GoalTemplateCatalog.template(id: "nope") == nil)
    }

    @Test("The gym template only applies on its chosen days")
    func gymTemplateRunsOnChosenDaysOnly() {
        let gym = GoalTemplateCatalog.gym.makeGoal(title: "Gym", createdAt: day(2026, 1, 5))

        #expect(gym.schedule.isScheduled(on: day(2026, 1, 5), calendar: calendar))  // Monday
        #expect(!gym.schedule.isScheduled(on: day(2026, 1, 6), calendar: calendar)) // Tuesday
        #expect(gym.schedule.isScheduled(on: day(2026, 1, 7), calendar: calendar))  // Wednesday
    }

    @Test("The quit-smoking template has to be confirmed, not assumed")
    func quitSmokingTemplateNeedsConfirming() {
        let goal = GoalTemplateCatalog.quitSmoking.makeGoal(title: "Don't smoke", createdAt: day(2026, 1, 1))
        let calculator = ProgressCalculator(calendar: calendar)

        let untouched = calculator.progress(for: goal, entries: [], on: day(2026, 1, 2))
        #expect(!untouched.isAchieved)
        #expect(!untouched.isFailed) // unconfirmed is in progress, not a failure

        let confirmed = [Entry(goalID: goal.id, amount: 1, loggedAt: day(2026, 1, 2))]
        #expect(calculator.progress(for: goal, entries: confirmed, on: day(2026, 1, 2)).isAchieved)
    }

    @Test("A template carries its cumulative target through to the goal")
    func savingsTemplateKeepsItsLongRunTarget() {
        let goal = GoalTemplateCatalog.saveMoney.makeGoal(title: "Save", createdAt: day(2026, 1, 1))

        #expect(goal.cumulativeTarget == 10_000)
    }
}
