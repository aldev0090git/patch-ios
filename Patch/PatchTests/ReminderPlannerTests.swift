import Foundation
import PatchCore
import Testing
@testable import Patch

@Suite("Reminder planning")
struct ReminderPlannerTests {
    private func goal(
        schedule: Schedule = .daily,
        reminder: Reminder? = Reminder(hour: 20, minute: 0),
        archived: Bool = false
    ) -> Goal {
        Goal(
            title: "Read",
            measure: .minutes(20),
            schedule: schedule,
            reminder: reminder,
            archivedAt: archived ? .now : nil
        )
    }

    @Test("A daily goal needs one repeating notification, not seven")
    func dailyGoalPlansOne() {
        let plan = ReminderPlanner.plan(for: goal())
        #expect(plan.count == 1)
        #expect(plan.first?.weekday == nil)
        #expect(plan.first?.components.hour == 20)
    }

    @Test("A goal on certain days needs one per day, and only those days")
    func weekdayGoalPlansOnePerDay() {
        let plan = ReminderPlanner.plan(
            for: goal(schedule: .daysOfWeek([.monday, .wednesday, .friday]))
        )

        #expect(plan.count == 3)
        #expect(Set(plan.compactMap(\.weekday)) == [2, 4, 6])
    }

    @Test("A goal on dates of the month gets one monthly notification per date")
    func monthlyGoalPlansOnePerDate() {
        let plan = ReminderPlanner.plan(for: goal(schedule: .daysOfMonth([1, 15])))

        #expect(plan.count == 2)
        #expect(Set(plan.compactMap(\.dayOfMonth)) == [1, 15])
        // No weekday: a trigger with a day but no month repeats monthly, which
        // is the whole point. A weekday as well would mean "the 1st, if it is
        // a Monday".
        #expect(plan.allSatisfy { $0.weekday == nil })
        #expect(plan.allSatisfy { $0.components.day != nil })
        #expect(plan.allSatisfy { $0.components.month == nil })
    }

    @Test("Date and weekday reminders never collide on an identifier")
    func dateAndWeekdayIdentifiersDiffer() {
        let byDate = ReminderPlanner.plan(for: goal(schedule: .daysOfMonth([2])))
        let byWeekday = ReminderPlanner.plan(for: goal(schedule: .daysOfWeek([.monday])))

        #expect(byDate.first?.id != byWeekday.first?.id)
    }

    @Test("A goal with no reminder is never scheduled")
    func noReminderNoNotification() {
        #expect(ReminderPlanner.plan(for: goal(reminder: nil)).isEmpty)
    }

    @Test("An archived goal stops reminding you about itself")
    func archivedGoalsAreDropped() {
        // Being nagged about something you put away is the fastest way to
        // have notifications turned off for good.
        #expect(ReminderPlanner.plan(for: goal(archived: true)).isEmpty)
        #expect(ReminderPlanner.plan(for: [goal(archived: true)]).isEmpty)
    }

    @Test("Identifiers are derived from the goal, so rescheduling replaces")
    func identifiersAreStable() {
        let goal = goal()
        let first = ReminderPlanner.plan(for: goal).map(\.id)
        let second = ReminderPlanner.plan(for: goal).map(\.id)

        #expect(first == second)
        #expect(first.allSatisfy { $0.contains(goal.id.uuidString) })
    }

    @Test("Two goals never share an identifier")
    func identifiersAreUnique() {
        let plan = ReminderPlanner.plan(for: [
            goal(schedule: .daysOfWeek([.monday, .tuesday])),
            goal(),
            goal(schedule: .daysOfWeek([.monday]))
        ])

        #expect(Set(plan.map(\.id)).count == plan.count)
    }

    @Test("The weekday travels into the trigger, or the reminder fires daily")
    func weekdayReachesTheComponents() {
        let plan = ReminderPlanner.plan(for: goal(schedule: .daysOfWeek([.sunday])))
        let components = try? #require(plan.first?.components)

        #expect(components?.weekday == 1)
        #expect(components?.hour == 20)
        #expect(components?.minute == 0)
    }

    @Test("Planning a list leaves out the goals that want nothing")
    func listPlanningFiltersCorrectly() {
        let plan = ReminderPlanner.plan(for: [
            goal(),
            goal(reminder: nil),
            goal(archived: true),
            goal(schedule: .daysOfWeek([.saturday, .sunday]))
        ])

        #expect(plan.count == 3)
    }
}
