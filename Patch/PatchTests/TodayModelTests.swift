import Foundation
import PatchCore
import Testing
@testable import Patch

/// A store that refuses everything, for checking the failure paths.
@MainActor
private final class FailingStore: GoalStore {
    struct Nope: Error, LocalizedError {
        var errorDescription: String? { "disk on fire" }
    }

    func loadGoals() throws -> [Goal] { throw Nope() }
    func loadEntries() throws -> [Entry] { throw Nope() }
    func save(_ goal: Goal) throws { throw Nope() }
    func log(_ entry: Entry) throws { throw Nope() }
    func deleteEntries(ids: [Entry.ID]) throws { throw Nope() }
    func deleteGoal(id: Goal.ID) throws { throw Nope() }
}

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}

@Suite("Today model")
struct TodayModelTests {
    @MainActor
    @Test("Loading brings goals and entries in from the store")
    func loadReadsFromTheStore() {
        let goal = Goal(title: "Read", measure: .minutes(20))
        let store = InMemoryGoalStore(goals: [goal], entries: [Entry(goalID: goal.id, amount: 600)])
        let model = TodayModel(store: store)

        model.load()

        #expect(model.goals.count == 1)
        #expect(model.entries.count == 1)
        #expect(model.failure == nil)
    }

    @MainActor
    @Test("Logging shows on screen and reaches the store")
    func loggingPersists() throws {
        let goal = Goal(title: "Water", measure: .millilitres(2000))
        let store = InMemoryGoalStore(goals: [goal])
        let model = TodayModel(store: store)
        model.load()

        model.log(500, for: goal)

        #expect(model.progress(for: goal).total == 500)
        #expect(try store.loadEntries().count == 1)
    }

    @MainActor
    @Test("Resetting clears today for one goal and leaves the others alone")
    func resetIsScopedToOneGoal() throws {
        let water = Goal(title: "Water", measure: .millilitres(2000))
        let read = Goal(title: "Read", measure: .minutes(20))
        let store = InMemoryGoalStore(goals: [water, read])
        let model = TodayModel(store: store)
        model.load()
        model.log(500, for: water)
        model.log(500, for: water)
        model.log(600, for: read)

        model.resetToday(for: water)

        #expect(model.progress(for: water).total == 0)
        #expect(model.progress(for: read).total == 600)
        #expect(try store.loadEntries().count == 1)
    }

    @MainActor
    @Test("Resetting leaves earlier days untouched")
    func resetKeepsHistory() throws {
        let calendar = utcCalendar()
        let goal = Goal(title: "Water", measure: .millilitres(2000))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) ?? .now
        let store = InMemoryGoalStore(
            goals: [goal],
            entries: [Entry(goalID: goal.id, amount: 750, loggedAt: yesterday)]
        )
        let model = TodayModel(store: store, calendar: calendar)
        model.load()
        model.log(500, for: goal)

        model.resetToday(for: goal)

        // Today is cleared; yesterday's 750 ml is still on the record.
        #expect(model.progress(for: goal).total == 0)
        #expect(try store.loadEntries().count == 1)
    }

    @MainActor
    @Test("Resetting a goal with nothing logged does nothing")
    func resetWithNothingLoggedIsANoOp() {
        let goal = Goal(title: "Read", measure: .minutes(20))
        let model = TodayModel(store: InMemoryGoalStore(goals: [goal]))
        model.load()

        model.resetToday(for: goal)

        #expect(model.failure == nil)
        #expect(model.entries.isEmpty)
    }

    @MainActor
    @Test("Saving a new goal adds it; saving again updates in place")
    func savingCreatesThenUpdates() {
        let model = TodayModel(store: InMemoryGoalStore())
        model.load()
        var goal = Goal(title: "Read", measure: .minutes(20))

        model.save(goal)
        #expect(model.goals.count == 1)

        goal.title = "Read a book"
        model.save(goal)

        #expect(model.goals.count == 1)
        #expect(model.goals.first?.title == "Read a book")
    }

    @MainActor
    @Test("Archiving hides the goal from today but keeps its entries")
    func archivingHidesWithoutDeleting() {
        let goal = Goal(title: "Read", measure: .minutes(20))
        let model = TodayModel(store: InMemoryGoalStore(goals: [goal]))
        model.load()
        model.log(600, for: goal)

        model.archive(goal)

        #expect(model.todaysGoals.isEmpty)
        #expect(model.goals.count == 1)
        #expect(model.goals.first?.isArchived == true)
        #expect(model.entries.count == 1)
    }

    @MainActor
    @Test("A day with nothing scheduled is not a day you finished")
    func emptyDayIsNotComplete() {
        let model = TodayModel(store: InMemoryGoalStore())
        model.load()

        // Nothing to do is not the same as everything done. Congratulating
        // someone for a day they never started is a lie they will notice.
        #expect(!model.isDayComplete)
    }

    @MainActor
    @Test("The day is complete only once the last scheduled goal is met")
    func dayCompletesOnTheLastGoal() {
        let water = Goal(title: "Water", measure: .millilitres(1000))
        let read = Goal(title: "Read", measure: .minutes(10))
        let model = TodayModel(store: InMemoryGoalStore(goals: [water, read]))
        model.load()

        model.log(1000, for: water)
        #expect(!model.isDayComplete)

        model.log(600, for: read)
        #expect(model.isDayComplete)

        // And it comes undone again, so the celebration can happen twice if
        // the user undoes and redoes the last goal.
        model.resetToday(for: read)
        #expect(!model.isDayComplete)
    }

    @MainActor
    @Test("An archived goal cannot hold the day open")
    func archivedGoalsDoNotCount() {
        let water = Goal(title: "Water", measure: .millilitres(1000))
        let abandoned = Goal(title: "Gym", measure: .times(1))
        let model = TodayModel(store: InMemoryGoalStore(goals: [water, abandoned]))
        model.load()
        model.log(1000, for: water)

        #expect(!model.isDayComplete)
        model.archive(abandoned)
        #expect(model.isDayComplete)
    }

    @MainActor
    @Test("Today only shows goals scheduled for today")
    func todayRespectsTheSchedule() {
        let calendar = utcCalendar()
        let today = Weekday(rawValue: calendar.component(.weekday, from: .now))
        let otherDay = Weekday.allCases.first { $0 != today }

        let daily = Goal(title: "Read", measure: .minutes(20))
        let elsewhere = Goal(
            title: "Gym",
            measure: .times(1),
            schedule: .daysOfWeek([otherDay ?? .monday])
        )
        let model = TodayModel(store: InMemoryGoalStore(goals: [daily, elsewhere]), calendar: calendar)

        model.load()

        #expect(model.todaysGoals.map(\.id) == [daily.id])
    }
}

@Suite("Today model failures")
struct TodayModelFailureTests {
    @MainActor
    @Test("A store that cannot be read surfaces a message rather than failing silently")
    func loadFailureIsSurfaced() {
        let model = TodayModel(store: FailingStore())

        model.load()

        #expect(model.failure != nil)
    }

    @MainActor
    @Test("A log that cannot be written is reported, not quietly dropped")
    func logFailureIsSurfaced() {
        let model = TodayModel(store: FailingStore())
        let goal = Goal(title: "Read", measure: .minutes(20))

        model.log(600, for: goal)

        // Losing a logged entry without saying so is worse than an alert.
        #expect(model.failure != nil)
        #expect(model.entries.isEmpty)
    }
}
