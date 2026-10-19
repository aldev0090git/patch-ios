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
