import Foundation
import PatchCore
import SwiftData
import Testing
@testable import PatchStore

/// One container for the whole suite, emptied between tests.
///
/// Creating a second `ModelContainer` in the same process traps with SIGTRAP —
/// not on the second *concurrent* one, on the second one at all, serialized or
/// not. Every test building its own container therefore killed the run with no
/// usable diagnostic.
@MainActor
private enum SharedContainer {
    static let value: ModelContainer? = {
        let schema = Schema([StoredGoal.self, StoredEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try? ModelContainer(for: schema, configurations: configuration)
    }()
}

// Serialized because the tests share one container, so they must not interleave
// while emptying it.
@Suite("SwiftData store", .serialized)
struct SwiftDataGoalStoreTests {
    @MainActor
    private func makeStore() throws -> SwiftDataGoalStore {
        let container = try #require(SharedContainer.value)
        let context = container.mainContext
        try context.delete(model: StoredGoal.self)
        try context.delete(model: StoredEntry.self)
        try context.save()
        return SwiftDataGoalStore(context: context)
    }

    @Test("A goal's Health link and an entry's source survive a round trip")
    @MainActor
    func healthFieldsRoundTrip() throws {
        let store = try makeStore()
        let goal = Goal(title: "Steps", measure: .steps(10_000), healthSource: .steps)
        try store.save(goal)
        try store.log(Entry(goalID: goal.id, amount: 4000, source: .health))
        try store.log(Entry(goalID: goal.id, amount: 1000, source: .manual))

        #expect(try store.loadGoals().first?.healthSource == .steps)
        #expect(try store.loadEntries().map(\.source) == [.health, .manual])
    }

    @Test("A goal with no Health link comes back with none, not a default")
    @MainActor
    func absentHealthLinkStaysAbsent() throws {
        // The failure this guards against is a row written before the field
        // existed reading back as linked, which would start importing into a
        // goal the user never pointed at Health.
        let store = try makeStore()
        try store.save(Goal(title: "Push-ups", measure: .times(20)))
        try store.log(Entry(goalID: UUID(), amount: 5))

        #expect(try store.loadGoals().first?.healthSource == nil)
        #expect(try store.loadEntries().first?.source == .manual)
    }

    @Test("A goal survives a round trip with every field intact")
    @MainActor
    func goalRoundTrip() throws {
        let store = try makeStore()
        let goal = Goal(
            title: "Gym",
            symbolName: "dumbbell",
            measure: .times(3),
            direction: .atLeast,
            schedule: .daysOfWeek([.monday, .wednesday, .friday]),
            cumulativeTarget: 150,
            createdAt: Date(timeIntervalSince1970: 1_767_225_600)
        )

        try store.save(goal)
        let restored = try #require(try store.loadGoals().first)

        #expect(restored.id == goal.id)
        #expect(restored.title == "Gym")
        #expect(restored.symbolName == "dumbbell")
        #expect(restored.measure == goal.measure)
        #expect(restored.direction == .atLeast)
        #expect(restored.schedule == .daysOfWeek([.monday, .wednesday, .friday]))
        #expect(restored.cumulativeTarget == 150)
        #expect(restored.createdAt == goal.createdAt)
        #expect(restored.archivedAt == nil)
    }

    @Test("A template goal keeps its title key, so it stays translatable")
    @MainActor
    func titleKeyRoundTrip() throws {
        let store = try makeStore()
        try store.save(GoalTemplateCatalog.water.makeGoal(title: "Water"))

        let restored = try #require(try store.loadGoals().first)
        #expect(restored.titleKey == "template.water")
        #expect(restored.title == "Water")
    }

    @Test("A goal with no title key round trips without growing one")
    @MainActor
    func absentTitleKeyStaysAbsent() throws {
        let store = try makeStore()
        try store.save(Goal(title: "Walk the dog", measure: .times(1)))

        #expect(try store.loadGoals().first?.titleKey == nil)
    }

    @Test("Target history survives a round trip, so the past stays judged correctly")
    @MainActor
    func targetHistoryRoundTrip() throws {
        let store = try makeStore()
        let goal = Goal(title: "Read", measure: .minutes(20))
            .withTarget(3600, changedOn: Date(timeIntervalSince1970: 1_767_225_600))

        try store.save(goal)
        let restored = try #require(try store.loadGoals().first)

        #expect(restored.targetHistory.count == 2)
        #expect(restored.targetHistory == goal.targetHistory)
        #expect(restored.measure.dailyTarget == 3600)
    }

    @Test("A goal that never changed its target stores no history")
    @MainActor
    func absentHistoryStaysAbsent() throws {
        let store = try makeStore()
        try store.save(Goal(title: "Read", measure: .minutes(20)))

        #expect(try store.loadGoals().first?.targetHistory.isEmpty == true)
    }

    @Test("A date-of-month schedule survives a round trip")
    @MainActor
    func monthlyScheduleRoundTrip() throws {
        let store = try makeStore()
        try store.save(Goal(
            title: "Save",
            measure: .money(5000),
            schedule: .daysOfMonth([1, 15])
        ))

        #expect(try store.loadGoals().first?.schedule == .daysOfMonth([1, 15]))
    }

    @Test("A long-run target and its deadline survive a round trip")
    @MainActor
    func cumulativeRoundTrip() throws {
        let store = try makeStore()
        let deadline = Date(timeIntervalSince1970: 1_800_000_000)
        try store.save(Goal(
            title: "Save",
            measure: .money(5000),
            cumulativeTarget: 100_000,
            cumulativeDeadline: deadline
        ))

        let restored = try #require(try store.loadGoals().first)
        #expect(restored.cumulativeTarget == 100_000)
        #expect(restored.cumulativeDeadline == deadline)
    }

    @Test("A daily schedule round trips as daily")
    @MainActor
    func dailyScheduleRoundTrip() throws {
        let store = try makeStore()
        try store.save(Goal(title: "Read", measure: .minutes(20), schedule: .daily))

        #expect(try store.loadGoals().first?.schedule == .daily)
    }

    @Test("Saving the same goal again updates it instead of duplicating")
    @MainActor
    func savingTwiceUpdates() throws {
        let store = try makeStore()
        var goal = Goal(title: "Read", measure: .minutes(20))
        try store.save(goal)

        goal.title = "Read a book"
        goal.archivedAt = Date(timeIntervalSince1970: 1_767_225_600)
        try store.save(goal)

        let stored = try store.loadGoals()
        #expect(stored.count == 1)
        #expect(stored.first?.title == "Read a book")
        #expect(stored.first?.isArchived == true)
    }

    @Test("Entries survive a round trip and keep their order")
    @MainActor
    func entryRoundTrip() throws {
        let store = try makeStore()
        let goalID = UUID()
        let morning = Entry(goalID: goalID, amount: 600,
                            loggedAt: Date(timeIntervalSince1970: 1_767_254_400), note: "chapter 1")
        let evening = Entry(goalID: goalID, amount: 900,
                            loggedAt: Date(timeIntervalSince1970: 1_767_297_600))

        try store.log(evening)
        try store.log(morning)

        let stored = try store.loadEntries()
        #expect(stored.map(\.id) == [morning.id, evening.id]) // sorted by time, not insertion
        #expect(stored.first?.amount == 600)
        #expect(stored.first?.note == "chapter 1")
        #expect(stored.last?.note == nil)
    }

    @Test("Deleting removes only the entries named")
    @MainActor
    func deletingIsSelective() throws {
        let store = try makeStore()
        let goalID = UUID()
        let keep = Entry(goalID: goalID, amount: 250)
        let dropOne = Entry(goalID: goalID, amount: 500)
        let dropTwo = Entry(goalID: goalID, amount: 750)
        for entry in [keep, dropOne, dropTwo] { try store.log(entry) }

        try store.deleteEntries(ids: [dropOne.id, dropTwo.id])

        #expect(try store.loadEntries().map(\.id) == [keep.id])
    }

    @Test("Deleting nothing is a no-op rather than an error")
    @MainActor
    func deletingNothingIsHarmless() throws {
        let store = try makeStore()
        try store.log(Entry(goalID: UUID(), amount: 1))

        try store.deleteEntries(ids: [])

        #expect(try store.loadEntries().count == 1)
    }

    @Test("A decimal amount is not mangled into a float")
    @MainActor
    func decimalPrecisionSurvives() throws {
        let store = try makeStore()
        // Money is the reason amounts are Decimal; 0.1 + 0.2 must stay exact.
        try store.log(Entry(goalID: UUID(), amount: Decimal(string: "1234.56") ?? 0))

        #expect(try store.loadEntries().first?.amount == Decimal(string: "1234.56"))
    }

    @Test("An unrecognised stored value falls back instead of failing")
    @MainActor
    func unknownRawValuesFallBack() throws {
        // A newer version syncing an unfamiliar measure kind must not stop an
        // older one from opening the goal at all.
        let stored = StoredGoal(Goal(title: "Mystery", measure: .times(5)))
        stored.measureKindRaw = "quantum-flux"
        stored.directionRaw = "sideways"

        let goal = stored.domain

        #expect(goal.measure.kind == .count)
        #expect(goal.direction == .atLeast)
        #expect(goal.title == "Mystery")
    }
}
