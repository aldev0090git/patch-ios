import Foundation
import Testing
@testable import PatchCore

@MainActor
@Suite("In-memory store")
struct InMemoryGoalStoreTests {
    @Test("A saved goal comes back")
    func goalsRoundTrip() throws {
        let store = InMemoryGoalStore()
        let goal = Goal(title: "Read", measure: .minutes(20))

        try store.save(goal)

        #expect(try store.loadGoals().map(\.id) == [goal.id])
    }

    @Test("Saving the same goal twice updates it rather than duplicating it")
    func savingTwiceUpdates() throws {
        let store = InMemoryGoalStore()
        var goal = Goal(title: "Read", measure: .minutes(20))
        try store.save(goal)

        goal.title = "Read a book"
        try store.save(goal)

        let stored = try store.loadGoals()
        #expect(stored.count == 1)
        #expect(stored.first?.title == "Read a book")
    }

    @Test("Archiving is just a save, and the goal stays in the store")
    func archivingKeepsHistory() throws {
        let store = InMemoryGoalStore()
        var goal = Goal(title: "Read", measure: .minutes(20))
        try store.save(goal)

        goal.archivedAt = .now
        try store.save(goal)

        let stored = try store.loadGoals()
        #expect(stored.count == 1)
        #expect(stored.first?.isArchived == true)
    }

    @Test("Logged entries come back in the order they were added")
    func entriesRoundTrip() throws {
        let store = InMemoryGoalStore()
        let goal = Goal(title: "Water", measure: .millilitres(2000))
        let first = Entry(goalID: goal.id, amount: 250)
        let second = Entry(goalID: goal.id, amount: 500)

        try store.log(first)
        try store.log(second)

        #expect(try store.loadEntries().map(\.id) == [first.id, second.id])
    }

    @Test("Deleting entries removes only the ones named")
    func deletingIsSelective() throws {
        let store = InMemoryGoalStore()
        let goal = Goal(title: "Water", measure: .millilitres(2000))
        let keep = Entry(goalID: goal.id, amount: 250)
        let drop = Entry(goalID: goal.id, amount: 500)
        try store.log(keep)
        try store.log(drop)

        try store.deleteEntries(ids: [drop.id])

        #expect(try store.loadEntries().map(\.id) == [keep.id])
    }

    @Test("Deleting an id that is not there is not an error")
    func deletingUnknownIsHarmless() throws {
        let store = InMemoryGoalStore()
        let entry = Entry(goalID: UUID(), amount: 1)
        try store.log(entry)

        try store.deleteEntries(ids: [UUID()])

        #expect(try store.loadEntries().count == 1)
    }

    @Test("A store seeded with data starts with it")
    func seedingWorks() throws {
        let goal = Goal(title: "Read", measure: .minutes(20))
        let entry = Entry(goalID: goal.id, amount: 600)
        let store = InMemoryGoalStore(goals: [goal], entries: [entry])

        #expect(try store.loadGoals().count == 1)
        #expect(try store.loadEntries().count == 1)
    }
    @Test("Deleting a goal removes it and everything logged against it")
    @MainActor
    func deleteGoal() throws {
        let doomed = Goal(title: "Mistake", measure: .times(1))
        let keep = Goal(title: "Real", measure: .times(1))
        let store = InMemoryGoalStore(
            goals: [doomed, keep],
            entries: [
                Entry(goalID: doomed.id, amount: 1),
                Entry(goalID: keep.id, amount: 2)
            ]
        )

        try store.deleteGoal(id: doomed.id)

        #expect(try store.loadGoals().map(\.title) == ["Real"])
        #expect(try store.loadEntries().map(\.goalID) == [keep.id])
    }

}
