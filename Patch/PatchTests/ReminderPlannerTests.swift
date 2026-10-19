import Foundation
import PatchCore
import Testing
@testable import Patch

@Suite("Daily check-ins")
struct DailyCheckInsTests {
    @Test("The standard pair is midday and mid-evening")
    func standardTimes() {
        #expect(DailyCheckIns.standard == [Reminder(hour: 12, minute: 0),
                                           Reminder(hour: 20, minute: 0)])
    }

    @Test("Times survive a round trip through the stored string")
    func roundTrip() {
        let times = [Reminder(hour: 7, minute: 5), Reminder(hour: 19, minute: 30)]
        #expect(DailyCheckIns.parse(DailyCheckIns.text(times)) == times)
        #expect(DailyCheckIns.text(times) == "07:05,19:30")
    }

    @Test("A stored string that makes no sense yields no times rather than wrong ones")
    func rubbishIsDropped() {
        // Whatever is in UserDefaults is not necessarily what this build put
        // there — an older version, a restored backup, a typo in a launch
        // argument. None of those should schedule a notification at 25:00.
        #expect(DailyCheckIns.parse("").isEmpty)
        #expect(DailyCheckIns.parse("not a time").isEmpty)
        #expect(DailyCheckIns.parse("25:00,12:70").isEmpty)
        #expect(DailyCheckIns.parse("12:00,rubbish") == [Reminder(hour: 12, minute: 0)])
    }

    @Test("Times are sorted and de-duplicated, whatever order they arrive in")
    func normalisation() {
        let messy = [Reminder(hour: 20, minute: 0),
                     Reminder(hour: 8, minute: 0),
                     Reminder(hour: 20, minute: 0)]
        #expect(DailyCheckIns.normalised(messy) == [Reminder(hour: 8, minute: 0),
                                                    Reminder(hour: 20, minute: 0)])
    }

    @Test("No more than four, however many are asked for")
    func capped() {
        let many = (0..<10).map { Reminder(hour: $0, minute: 0) }
        #expect(DailyCheckIns.normalised(many).count == DailyCheckIns.maximum)
    }

    @Test("Adding a time suggests one that is not already in the list")
    func suggestionIsNew() {
        let times = DailyCheckIns.standard
        let suggestion = DailyCheckIns.suggestedAddition(after: times)
        #expect(!times.contains(suggestion))
        // Tapping Add twice must give two rows, not one row twice over.
        #expect(DailyCheckIns.normalised(times + [suggestion]).count == times.count + 1)
    }

    @Test("Adding to an empty list suggests a sensible first time")
    func suggestionFromNothing() {
        #expect(DailyCheckIns.suggestedAddition(after: []) == DailyCheckIns.standard[0])
    }

    @Test("A late time cannot be pushed past midnight")
    func suggestionStaysInTheDay() {
        let suggestion = DailyCheckIns.suggestedAddition(after: [Reminder(hour: 23, minute: 30)])
        #expect(suggestion.hour == 23)
    }
}

@Suite("Reminder planning")
struct ReminderPlannerTests {
    @Test("One notification per check-in, and no more")
    func oneRequestPerTime() {
        let plan = ReminderPlanner.plan(times: DailyCheckIns.standard)

        #expect(plan.count == 2)
        #expect(plan.map(\.hour) == [12, 20])
    }

    @Test("Switching reminders off plans nothing, whatever times are stored")
    func disabledPlansNothing() {
        // The times stay in storage so turning it back on restores them, so
        // the switch — not the list — has to be what silences iOS.
        #expect(ReminderPlanner.plan(times: DailyCheckIns.standard, isEnabled: false).isEmpty)
    }

    @Test("The plan can never approach the 64 iOS allows")
    func cannotExhaustTheNotificationBudget() {
        // This is the bug that made per-goal reminders fail silently: ten
        // weekday goals asked for seventy requests and iOS kept the soonest
        // 64. Four is the ceiling now, and it is a ceiling by construction.
        let absurd = (0..<24).map { Reminder(hour: $0, minute: 0) }
        #expect(ReminderPlanner.plan(times: absurd).count <= DailyCheckIns.maximum)
    }

    @Test("Identifiers are stable, so re-syncing replaces rather than piles up")
    func identifiersAreStable() {
        let first = ReminderPlanner.plan(times: DailyCheckIns.standard).map(\.id)
        let second = ReminderPlanner.plan(times: DailyCheckIns.standard).map(\.id)

        #expect(first == second)
        #expect(Set(first).count == first.count)
    }

    @Test("Two times in the same hour get different identifiers")
    func identifiersIncludeTheMinute() {
        let plan = ReminderPlanner.plan(times: [Reminder(hour: 9, minute: 0),
                                                Reminder(hour: 9, minute: 30)])
        #expect(Set(plan.map(\.id)).count == 2)
    }

    @Test("The trigger carries a time and no day, which is what makes it repeat daily")
    func componentsRepeatDaily() throws {
        let plan = try #require(ReminderPlanner.plan(times: [Reminder(hour: 7, minute: 15)]).first)

        #expect(plan.components.hour == 7)
        #expect(plan.components.minute == 15)
        #expect(plan.components.weekday == nil)
        #expect(plan.components.day == nil)
    }
}
