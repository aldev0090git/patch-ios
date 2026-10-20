import Foundation
import Testing
@testable import PatchCore

@Suite("The order goals appear in")
struct GoalOrderTests {
    /// What the store would do with the returned changes.
    private func apply(_ changed: [Goal], to all: [Goal]) -> [Goal] {
        all.map { original in changed.first { $0.id == original.id } ?? original }
    }

    private func goal(_ title: String, created: Int, sortIndex: Int = 0) -> Goal {
        Goal(
            title: title,
            measure: .times(1),
            createdAt: day(2026, 3, created),
            sortIndex: sortIndex
        )
    }

    // MARK: - Falling back

    @Test("With nothing arranged, goals stay in the order they were created")
    func fallsBackToCreationDate() {
        // The whole point of the fallback: introducing `sortIndex` must not
        // silently shuffle the list of anyone who upgrades.
        let goals = [goal("Third", created: 3), goal("First", created: 1), goal("Second", created: 2)]
        #expect(GoalOrder.sorted(goals).map(\.title) == ["First", "Second", "Third"])
    }

    @Test("An arranged order wins over the creation date")
    func sortIndexWins() {
        let goals = [
            goal("Oldest", created: 1, sortIndex: 2),
            goal("Newest", created: 3, sortIndex: 0),
            goal("Middle", created: 2, sortIndex: 1)
        ]
        #expect(GoalOrder.sorted(goals).map(\.title) == ["Newest", "Middle", "Oldest"])
    }

    // MARK: - Dragging

    @Test("Swapping two goals puts them in the order asked for")
    func swap() {
        let read = goal("Read", created: 1)
        let water = goal("Water", created: 2)
        let steps = goal("Steps", created: 3)
        let all = [read, water, steps]

        let changed = GoalOrder.reindexed(all: all, visibleOrder: [water.id, read.id, steps.id])

        #expect(GoalOrder.sorted(apply(changed, to: all)).map(\.title) == ["Water", "Read", "Steps"])
        // Water lands at index 0 and was already 0, so it needs no write.
        // Asserting on the contents of `changed` rather than on the order is
        // how the first version of this test managed to fail against correct
        // code.
        #expect(!changed.contains { $0.id == water.id }, "Wrote a goal that did not move")
    }

    @Test("Reordering settles: applying the result gives the order asked for")
    func roundTrip() {
        let all = [goal("A", created: 1), goal("B", created: 2), goal("C", created: 3)]
        let wanted = [all[2].id, all[0].id, all[1].id]

        let changed = GoalOrder.reindexed(all: all, visibleOrder: wanted)

        #expect(GoalOrder.sorted(apply(changed, to: all)).map(\.id) == wanted)
    }

    @Test("Dragging again does nothing when nothing moved")
    func noChangeWritesNothing() {
        let all = [goal("A", created: 1, sortIndex: 0), goal("B", created: 2, sortIndex: 1)]
        #expect(GoalOrder.reindexed(all: all, visibleOrder: [all[0].id, all[1].id]).isEmpty)
    }

    // MARK: - The arithmetic of a drag

    @Test("Dragging the first row down one lands it second")
    func dragDownOne() {
        // SwiftUI reports this as "move index 0 to offset 2", not 1: the
        // destination is a gap measured before the row is lifted out. Getting
        // that wrong is an off-by-one nobody notices until they try it.
        let goals = ["A", "B", "C"].enumerated().map { goal($1, created: $0 + 1) }
        let moved = GoalOrder.moved(goals, fromOffsets: [0], toOffset: 2)
        #expect(moved.map(\.title) == ["B", "A", "C"])
    }

    @Test("Dragging the last row to the top")
    func dragToTop() {
        let goals = ["A", "B", "C"].enumerated().map { goal($1, created: $0 + 1) }
        #expect(GoalOrder.moved(goals, fromOffsets: [2], toOffset: 0).map(\.title) == ["C", "A", "B"])
    }

    @Test("Dropping a row back where it started changes nothing")
    func dragNowhere() {
        let goals = ["A", "B", "C"].enumerated().map { goal($1, created: $0 + 1) }
        #expect(GoalOrder.moved(goals, fromOffsets: [1], toOffset: 1).map(\.title) == ["A", "B", "C"])
    }

    @Test("Moving several rows at once keeps them together and in order")
    func dragSeveral() {
        let goals = ["A", "B", "C", "D"].enumerated().map { goal($1, created: $0 + 1) }
        #expect(GoalOrder.moved(goals, fromOffsets: [0, 1], toOffset: 4).map(\.title)
            == ["C", "D", "A", "B"])
    }

    @Test("An offset past the end does not crash")
    func dragOutOfBounds() {
        let goals = ["A", "B"].enumerated().map { goal($1, created: $0 + 1) }
        #expect(GoalOrder.moved(goals, fromOffsets: [0], toOffset: 99).map(\.title) == ["B", "A"])
        #expect(GoalOrder.moved(goals, fromOffsets: [99], toOffset: 0).map(\.title) == ["A", "B"])
    }

    // MARK: - The goals that are not on screen

    @Test("A goal not scheduled today keeps its place when two visible ones swap")
    func hiddenGoalsHold() {
        // Today shows Read and Steps; Gym is weekdays-only and it is Sunday.
        // Dragging Steps above Read must not move Gym.
        let read = goal("Read", created: 1)
        let gym = goal("Gym", created: 2)
        let steps = goal("Steps", created: 3)

        let changed = GoalOrder.reindexed(
            all: [read, gym, steps],
            visibleOrder: [steps.id, read.id]
        )
        // Gym held slot 1; the two visible goals were dealt into slots 0 and 2.
        let updated = apply(changed, to: [read, gym, steps])
        #expect(GoalOrder.sorted(updated).map(\.title) == ["Steps", "Gym", "Read"])
    }

    @Test("Ids that are not in the list are ignored rather than crashing")
    func unknownIdsAreHarmless() {
        let read = goal("Read", created: 1)
        let water = goal("Water", created: 2)

        let all = [read, water]
        let changed = GoalOrder.reindexed(all: all, visibleOrder: [UUID(), water.id, read.id])

        #expect(GoalOrder.sorted(apply(changed, to: all)).map(\.title) == ["Water", "Read"])
    }

    @Test("An empty drag leaves everything alone")
    func emptyVisibleOrder() {
        let all = [goal("A", created: 1, sortIndex: 0), goal("B", created: 2, sortIndex: 1)]
        #expect(GoalOrder.reindexed(all: all, visibleOrder: []).isEmpty)
    }
}
