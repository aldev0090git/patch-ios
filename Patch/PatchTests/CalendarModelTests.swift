import Foundation
import PatchCore
import Testing
@testable import Patch

@Suite("Calendar model")
struct CalendarModelTests {
    /// Monday-first, so the grid padding is exercised against a first weekday
    /// that is not the Gregorian default.
    private func calendar(firstWeekday: Int = 2) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    @MainActor
    private func model(
        goals: [Goal] = [],
        entries: [Entry] = [],
        firstWeekday: Int = 2
    ) -> CalendarModel {
        let model = CalendarModel(
            store: InMemoryGoalStore(goals: goals, entries: entries),
            calendar: calendar(firstWeekday: firstWeekday)
        )
        model.load()
        return model
    }

    @MainActor
    @Test("The grid is always whole weeks, so the columns stay under their headings")
    func gridIsWholeWeeks() {
        let model = model()
        for month in -14...0 {
            model.month = calendar().date(byAdding: .month, value: month, to: .now) ?? .now
            #expect(model.days.count % 7 == 0, "month offset \(month) produced a ragged grid")
            #expect(model.days.count >= 28)
        }
    }

    @MainActor
    @Test("The grid starts on the locale's first weekday")
    func gridStartsOnFirstWeekday() {
        for firstWeekday in 1...7 {
            let model = model(firstWeekday: firstWeekday)
            let first = try? #require(model.days.first)
            let weekday = calendar(firstWeekday: firstWeekday)
                .component(.weekday, from: first?.date ?? .now)
            #expect(weekday == firstWeekday)
        }
    }

    @MainActor
    @Test("Weekday headings are rotated to match, and there are seven")
    func weekdaySymbolsAreRotated() {
        let sundayFirst = model(firstWeekday: 1).weekdaySymbols
        let mondayFirst = model(firstWeekday: 2).weekdaySymbols

        #expect(sundayFirst.count == 7)
        #expect(mondayFirst.count == 7)
        #expect(sundayFirst != mondayFirst)
        #expect(Set(sundayFirst) == Set(mondayFirst))
    }

    @MainActor
    @Test("Days outside the month on screen are marked, not dropped")
    func paddingDaysAreMarked() {
        let model = model()
        model.month = calendar().date(from: DateComponents(year: 2026, month: 3, day: 15)) ?? .now

        #expect(model.days.contains { !$0.isInMonth })
        #expect(model.days.filter(\.isInMonth).count == 31)
    }

    @MainActor
    @Test("Future days carry no verdict")
    func futureDaysAreNeutral() {
        let model = model()
        let future = model.days.filter(\.isFuture)

        for day in future {
            #expect(day.date > Date.now)
        }
    }

    @MainActor
    @Test("You cannot page forward out of the current month")
    func cannotPageIntoTheFuture() {
        let model = model()
        #expect(model.canStepForward == false)

        model.step(by: -1)
        #expect(model.canStepForward)
    }

    @MainActor
    @Test("Changing month drops a selection made in the old one")
    func steppingClearsSelection() {
        let model = model()
        model.selectedDay = calendar().startOfDay(for: .now)
        model.step(by: -1)

        #expect(model.selectedDay == nil)
    }

    @MainActor
    @Test("A finished day fills, an empty one does not")
    func completedDaysAreMarked() {
        let created = calendar().date(byAdding: .day, value: -10, to: .now) ?? .now
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: created)
        let yesterday = calendar().date(byAdding: .day, value: -1, to: .now) ?? .now
        let model = model(
            goals: [goal],
            entries: [Entry(goalID: goal.id, amount: 1200, loggedAt: yesterday)]
        )

        let done = model.days.first { calendar().isDate($0.date, inSameDayAs: yesterday) }
        #expect(done?.isComplete == true)

        let twoDaysAgo = calendar().date(byAdding: .day, value: -2, to: .now) ?? .now
        let empty = model.days.first { calendar().isDate($0.date, inSameDayAs: twoDaysAgo) }
        #expect(empty?.isComplete == false)
        #expect(empty?.hasAnything == true)
    }

    @MainActor
    @Test("A day before any goal existed has nothing on it, rather than misses")
    func daysBeforeTheGoalAreBlank() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: .now)
        let model = model(goals: [goal])
        let lastMonth = calendar().date(byAdding: .month, value: -1, to: .now) ?? .now
        model.month = lastMonth

        #expect(model.days.allSatisfy { !$0.hasAnything })
    }

    @MainActor
    @Test("Tapping a day lists the goals that were due on it")
    func selectedDayListsItsGoals() {
        let created = calendar().date(byAdding: .day, value: -10, to: .now) ?? .now
        let daily = Goal(title: "Read", measure: .minutes(20), createdAt: created)
        let sundays = Goal(
            title: "Long run",
            measure: .times(1),
            schedule: .daysOfWeek([.sunday]),
            createdAt: created
        )
        let model = model(goals: [daily, sundays])

        // A Monday, so the Sunday-only goal must not appear — and one the
        // goals already existed on. Without that second condition this test
        // passes or fails depending on where in the month it is run: on the
        // 19th the month's first Monday is older than `created`, both goals
        // are correctly filtered out as not-yet-created, and the expectation
        // below is left comparing against an empty list.
        let monday = model.days.first {
            calendar().component(.weekday, from: $0.date) == 2
                && !$0.isFuture && $0.isInMonth
                && $0.date >= calendar().startOfDay(for: created)
        }
        model.selectedDay = try? #require(monday?.date)

        #expect(model.selectedDayProgress.map(\.goal.title) == ["Read"])
    }

    @MainActor
    @Test("A goal created after the selected day is not listed as due on it")
    func goalsAreNotListedBeforeTheyExisted() {
        let fresh = Goal(title: "Fresh", measure: .minutes(20), createdAt: .now)
        let model = model(goals: [fresh])
        model.selectedDay = calendar().date(byAdding: .day, value: -3, to: .now)

        #expect(model.selectedDayProgress.isEmpty)
    }

    @MainActor
    @Test("A store that refuses to load surfaces the failure")
    func loadFailureIsSurfaced() {
        let model = CalendarModel(store: FailingCalendarStore(), calendar: calendar())
        model.load()

        #expect(model.failure != nil)
    }
}

@MainActor
private final class FailingCalendarStore: GoalStore {
    struct Nope: Error, LocalizedError {
        var errorDescription: String? { "disk on fire" }
    }

    func loadGoals() throws -> [Goal] { throw Nope() }
    func loadEntries() throws -> [Entry] { throw Nope() }
    func save(_ goal: Goal) throws { throw Nope() }
    func log(_ entry: Entry) throws { throw Nope() }
    func deleteEntries(ids: [Entry.ID]) throws { throw Nope() }
}

/// Logging against a day that has already passed.
///
/// The highest-voted complaint about every habit tracker in this category is
/// being unable to fix a day you forgot to tick, so these pin both that it
/// works and that it cannot write somewhere it should not.
@Suite("Backdating")
struct BackdatingTests {
    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }

    private func daysAgo(_ count: Int) -> Date {
        calendar().date(byAdding: .day, value: -count, to: .now) ?? .now
    }

    @MainActor
    private func model(goals: [Goal], entries: [Entry] = []) -> CalendarModel {
        let model = CalendarModel(
            store: InMemoryGoalStore(goals: goals, entries: entries),
            calendar: calendar()
        )
        model.load()
        return model
    }

    private func dailyGoal(createdDaysAgo: Int = 30) -> Goal {
        Goal(title: "Read", measure: .minutes(20), createdAt: daysAgo(createdDaysAgo))
    }

    @MainActor
    @Test("An amount logged on a past day lands on that day")
    func logsOntoThePastDay() {
        let goal = dailyGoal()
        let model = model(goals: [goal])
        let threeDaysAgo = daysAgo(3)

        model.log(600, for: goal, on: threeDaysAgo)

        #expect(model.progress(for: goal, on: threeDaysAgo).total == 600)
    }

    @MainActor
    @Test("Logging a past day leaves today alone")
    func todayIsUntouched() {
        let goal = dailyGoal()
        let model = model(goals: [goal])

        model.log(600, for: goal, on: daysAgo(3))

        // The bug this guards against is an entry stamped `.now` while the
        // screen claims it went to Tuesday.
        #expect(model.progress(for: goal, on: .now).total == 0)
    }

    @MainActor
    @Test("The entry reaches the store, not just the screen")
    func writesThrough() throws {
        let goal = dailyGoal()
        let store = InMemoryGoalStore(goals: [goal])
        let model = CalendarModel(store: store, calendar: calendar())
        model.load()

        model.log(600, for: goal, on: daysAgo(2))

        let saved = try #require(try store.loadEntries().first)
        #expect(calendar().isDate(saved.loggedAt, inSameDayAs: daysAgo(2)))
    }

    @MainActor
    @Test("A backdated entry is stamped midday, so a time zone change cannot move it")
    func stampedAtMidday() throws {
        let goal = dailyGoal()
        let store = InMemoryGoalStore(goals: [goal])
        let model = CalendarModel(store: store, calendar: calendar())
        model.load()

        model.log(600, for: goal, on: daysAgo(5))

        let saved = try #require(try store.loadEntries().first)
        #expect(calendar().component(.hour, from: saved.loggedAt) == 12)
    }

    @MainActor
    @Test("Tomorrow cannot be logged — nothing has happened yet")
    func theFutureIsClosed() {
        let goal = dailyGoal()
        let model = model(goals: [goal])
        let tomorrow = calendar().date(byAdding: .day, value: 1, to: .now) ?? .now

        #expect(!model.canLog(goal, on: tomorrow))
        model.log(600, for: goal, on: tomorrow)
        #expect(model.progress(for: goal, on: tomorrow).total == 0)
    }

    @MainActor
    @Test("Today itself can still be logged from the calendar")
    func todayIsWritable() {
        let goal = dailyGoal()
        let model = model(goals: [goal])

        #expect(model.canLog(goal, on: .now))
        model.log(600, for: goal, on: .now)
        #expect(model.progress(for: goal, on: .now).total == 600)
    }

    @MainActor
    @Test("A day before the goal existed cannot be logged")
    func beforeTheGoalExisted() {
        let goal = dailyGoal(createdDaysAgo: 5)
        let model = model(goals: [goal])

        #expect(!model.canLog(goal, on: daysAgo(10)))
        model.log(600, for: goal, on: daysAgo(10))
        #expect(model.progress(for: goal, on: daysAgo(10)).total == 0)
    }

    @MainActor
    @Test("A day the goal was not scheduled for cannot be logged")
    func unscheduledDaysAreClosed() {
        // An entry on an unscheduled day would count toward every total while
        // appearing on no screen that could take it back off again.
        let someDay = daysAgo(3)
        let weekday = calendar().component(.weekday, from: someDay)
        let elsewhere = Weekday.allCases.first { $0.rawValue != weekday } ?? .monday
        let goal = Goal(
            title: "Gym",
            measure: .times(1),
            schedule: .daysOfWeek([elsewhere]),
            createdAt: daysAgo(30)
        )
        let model = model(goals: [goal])

        #expect(!model.canLog(goal, on: someDay))
        model.log(1, for: goal, on: someDay)
        #expect(model.progress(for: goal, on: someDay).total == 0)
    }

    @MainActor
    @Test("An archived goal cannot be logged against")
    func archivedGoalsAreClosed() {
        var goal = dailyGoal()
        goal.archivedAt = .now
        let model = model(goals: [goal])

        #expect(!model.canLog(goal, on: daysAgo(3)))
    }

    @MainActor
    @Test("Clearing a day removes that day and no other")
    func clearingIsScopedToOneDay() {
        let goal = dailyGoal()
        let model = model(goals: [goal])
        model.log(600, for: goal, on: daysAgo(3))
        model.log(600, for: goal, on: daysAgo(4))

        model.clearDay(for: goal, on: daysAgo(3))

        #expect(model.progress(for: goal, on: daysAgo(3)).total == 0)
        #expect(model.progress(for: goal, on: daysAgo(4)).total == 600)
    }

    @MainActor
    @Test("Clearing one goal's day leaves the other goals on it")
    func clearingIsScopedToOneGoal() {
        let read = dailyGoal()
        let water = Goal(title: "Water", measure: .millilitres(2000), createdAt: daysAgo(30))
        let model = model(goals: [read, water])
        let day = daysAgo(2)
        model.log(600, for: read, on: day)
        model.log(500, for: water, on: day)

        model.clearDay(for: read, on: day)

        #expect(model.progress(for: read, on: day).total == 0)
        #expect(model.progress(for: water, on: day).total == 500)
    }

    @MainActor
    @Test("Clearing a day with nothing on it does nothing and reports nothing")
    func clearingNothingIsANoOp() {
        let goal = dailyGoal()
        let model = model(goals: [goal])

        model.clearDay(for: goal, on: daysAgo(3))

        #expect(model.failure == nil)
        #expect(model.entries.isEmpty)
    }

    @MainActor
    @Test("Filling in a missed day repairs the streak that ran through it")
    func repairingADayRepairsTheStreak() {
        // The whole point of the feature. A goal done on every day except one
        // has two short streaks; filling the gap must join them.
        let goal = dailyGoal()
        let model = model(goals: [goal])
        for day in 1...4 where day != 3 {
            model.log(1200, for: goal, on: daysAgo(day))
        }
        let streaks = StreakCalculator(calendar: calendar())
        let before = streaks.currentStreak(for: goal, entries: model.entries, asOf: daysAgo(1))
        #expect(before == 2)

        model.log(1200, for: goal, on: daysAgo(3))

        let after = streaks.currentStreak(for: goal, entries: model.entries, asOf: daysAgo(1))
        #expect(after == 4)
    }

    @MainActor
    @Test("A day only counts as written when something is actually on it")
    func hasLoggedTracksTheDay() {
        let goal = dailyGoal()
        let model = model(goals: [goal])

        #expect(!model.hasLogged(goal, on: daysAgo(3)))
        model.log(600, for: goal, on: daysAgo(3))
        #expect(model.hasLogged(goal, on: daysAgo(3)))
        #expect(!model.hasLogged(goal, on: daysAgo(4)))
    }

    @MainActor
    @Test("The future is not writable; everything up to today is")
    func writabilityFollowsTheSelectedDay() {
        let model = model(goals: [dailyGoal()])

        model.selectedDay = nil
        #expect(!model.isSelectedDayWritable)

        model.selectedDay = calendar().date(byAdding: .day, value: 1, to: .now)
        #expect(!model.isSelectedDayWritable)

        model.selectedDay = calendar().startOfDay(for: .now)
        #expect(model.isSelectedDayWritable)

        model.selectedDay = daysAgo(400)
        // Deliberately no lower bound: refusing to let someone fix a day is
        // the complaint this feature exists to answer.
        #expect(model.isSelectedDayWritable)
    }
}
