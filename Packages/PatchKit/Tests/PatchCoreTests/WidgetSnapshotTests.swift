import Foundation
import Testing
@testable import PatchCore

@Suite("Widget snapshot")
struct WidgetSnapshotTests {
    private let calendar = fixedCalendar()
    private let today = day(2026, 1, 5)

    private func goal(
        title: String = "Read",
        measure: Measure = .minutes(20),
        direction: Direction = .atLeast,
        schedule: Schedule = .daily
    ) -> Goal {
        Goal(
            title: title,
            measure: measure,
            direction: direction,
            schedule: schedule,
            createdAt: day(2026, 1, 1)
        )
    }

    private func snapshot(goals: [Goal], entries: [Entry]) -> WidgetSnapshot {
        WidgetSnapshot.today(
            goals: goals,
            entries: entries,
            titles: \.title,
            calendar: calendar,
            now: today
        )
    }

    @Test("Only goals due today reach the home screen")
    func onlyTodaysGoals() {
        let weekday = calendar.component(.weekday, from: today)
        let elsewhere = Weekday.allCases.first { $0.rawValue != weekday } ?? .monday
        let daily = goal()
        let other = goal(title: "Gym", measure: .times(1), schedule: .daysOfWeek([elsewhere]))

        #expect(snapshot(goals: [daily, other], entries: []).items.map(\.title) == ["Read"])
    }

    @Test("An archived goal is not on the home screen")
    func archivedGoalsAreLeftOut() {
        var abandoned = goal(title: "Gym")
        abandoned.archivedAt = today

        #expect(snapshot(goals: [abandoned], entries: []).items.isEmpty)
    }

    @Test("The overall figure averages every goal, not just the finished ones")
    func fractionAveragesProgress() {
        // Same rule as the Today header: a half-done morning reads as moving
        // rather than as nothing.
        let read = goal()
        let water = goal(title: "Water", measure: .millilitres(2000))
        let entries = [
            Entry(goalID: read.id, amount: 600, loggedAt: today),
            Entry(goalID: water.id, amount: 1000, loggedAt: today)
        ]

        let result = snapshot(goals: [read, water], entries: entries)

        #expect(result.fraction == 0.5)
        #expect(result.completed == 0)
        #expect(result.scheduled == 2)
    }

    @Test("An allowance fills as it is spent, not all at once")
    func allowanceUsesBudget() {
        // `fraction` is binary for `atMost` — it would read as a full ring
        // from midnight, which is what the Today card used to get wrong.
        let coffee = goal(title: "Coffee", measure: .times(2), direction: .atMost)
        let entries = [Entry(goalID: coffee.id, amount: 1, loggedAt: today)]

        #expect(snapshot(goals: [coffee], entries: entries).items.first?.fraction == 0.5)
    }

    @Test("A day with nothing scheduled is not a day you finished")
    func emptyDayIsNotComplete() {
        #expect(!snapshot(goals: [], entries: []).isComplete)
    }

    @Test("The day is complete only when every goal is")
    func completeWhenAllAchieved() {
        let read = goal()
        let water = goal(title: "Water", measure: .millilitres(2000))
        let entries = [
            Entry(goalID: read.id, amount: 1200, loggedAt: today),
            Entry(goalID: water.id, amount: 2000, loggedAt: today)
        ]

        #expect(snapshot(goals: [read, water], entries: entries).isComplete)
    }

    @Test("Titles come from the caller, so a template goal is not left in English")
    func titlesAreResolvedOutside() {
        // `PatchCore` has no business knowing the reader's language, and a
        // seeded goal stores a key rather than a word.
        let read = goal()
        let result = WidgetSnapshot.today(
            goals: [read],
            entries: [],
            titles: { _ in "Читати" },
            calendar: calendar,
            now: today
        )

        #expect(result.items.first?.title == "Читати")
    }

    @Test("A fraction outside 0...1 is clamped rather than drawn")
    func fractionIsClamped() {
        #expect(WidgetSnapshot.Item(
            id: UUID(), title: "x", symbolName: "x", fraction: 3, isAchieved: true
        ).fraction == 1)
        #expect(WidgetSnapshot.Item(
            id: UUID(), title: "x", symbolName: "x", fraction: -1, isAchieved: false
        ).fraction == 0)
    }

    @Test("What the app writes is what the widget reads")
    func roundTripsThroughTheStore() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = WidgetSnapshotStore(directory: directory)
        let read = goal()
        let written = snapshot(goals: [read], entries: [
            Entry(goalID: read.id, amount: 600, loggedAt: today)
        ])

        store.write(written)

        #expect(store.read() == written)
    }

    @Test("Nothing written yet reads as nothing, not as an empty day")
    func missingFileIsNil() {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        // A fresh install has no snapshot. The widget must say so rather than
        // claim the day is blank.
        #expect(WidgetSnapshotStore(directory: directory).read() == nil)
    }
}
