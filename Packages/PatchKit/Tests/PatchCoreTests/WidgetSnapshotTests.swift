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
    // MARK: - What the widget asks it

    @Test("The next thing to do is the first goal not yet finished")
    func nextUnfinished() {
        let snapshot = WidgetSnapshot(date: day(2026, 3, 10), items: [
            item("Read", achieved: true),
            item("Water", achieved: false),
            item("Steps", achieved: false)
        ])

        #expect(snapshot.nextUnfinished?.title == "Water")
        #expect(snapshot.remaining.map(\.title) == ["Water", "Steps"])
    }

    @Test("A finished day has nothing next, rather than an empty-looking goal")
    func nothingLeft() {
        let snapshot = WidgetSnapshot(date: day(2026, 3, 10), items: [
            item("Read", achieved: true),
            item("Water", achieved: true)
        ])

        #expect(snapshot.nextUnfinished == nil)
        #expect(snapshot.remaining.isEmpty)
    }

    @Test("A day with nothing scheduled has nothing next either")
    func emptyDay() {
        #expect(WidgetSnapshot(date: day(2026, 3, 10), items: []).nextUnfinished == nil)
    }

    private func item(_ title: String, achieved: Bool) -> WidgetSnapshot.Item {
        WidgetSnapshot.Item(
            id: UUID(),
            title: title,
            symbolName: "book",
            fraction: achieved ? 1 : 0.5,
            isAchieved: achieved
        )
    }

}

/// The file in the shared container outlives any one version of the app.
@Suite("Snapshot themes")
struct WidgetSnapshotThemeTests {
    @Test("A snapshot written before themes existed still reads")
    func olderSnapshotsStillDecode() throws {
        // Exactly what the previous build wrote: no `theme` key at all.
        let json = """
        {"date":"2026-10-21T00:00:00Z","items":[]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(WidgetSnapshot.self, from: Data(json.utf8))

        #expect(snapshot.theme == .plain)
    }

    @Test("A theme this build does not know falls back rather than failing")
    func unknownThemesFallBack() {
        #expect(PageTheme.stored("obsidian") == .standard)
        #expect(PageTheme.stored(nil) == .standard)
        #expect(PageTheme.stored("gold") == .gold)
    }

    @Test("A snapshot with no theme is plain, not the default")
    func olderSnapshotsAreNotRedressed() throws {
        // `decodeIfPresent ?? .plain`, deliberately: the absent key means a
        // build that had no themes, and that build's widget was the flat
        // one. Reading it as the new default would repaint a home screen
        // nobody asked to repaint, until the app next publishes.
        let json = #"{"date":"2026-10-21T00:00:00Z","items":[]}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode(WidgetSnapshot.self, from: Data(json.utf8)).theme == .plain)
    }

    @Test("Re-dressing keeps every number")
    func wearingChangesOnlyTheTheme() {
        let item = WidgetSnapshot.Item(
            id: UUID(), title: "Read", symbolName: "book", fraction: 0.5, isAchieved: false
        )
        let original = WidgetSnapshot(date: .now, items: [item], theme: .plain)
        let dressed = original.wearing(.roseGold)

        #expect(dressed.theme == .roseGold)
        #expect(dressed.items == original.items)
        #expect(dressed.date == original.date)
    }

    @Test("Every theme but the plain one has two stops, in both appearances")
    func themesAreComplete() {
        for theme in PageTheme.allCases where theme != .plain {
            #expect(theme.stops(dark: false)?.count == 2, "\(theme) has no light stops")
            #expect(theme.stops(dark: true)?.count == 2, "\(theme) has no dark stops")
        }
        #expect(PageTheme.plain.stops(dark: false) == nil)
    }

    /// White cards have nowhere to go, so the page has to stay clear of them.
    @Test("Light themes stay light enough for a white card to sit on")
    func lightThemesStayLight() throws {
        for theme in PageTheme.allCases where theme != .plain {
            let stops = try #require(theme.stops(dark: false))
            for stop in stops {
                let darkest = min(stop.red, stop.green, stop.blue)
                #expect(darkest > 0.70, "\(theme) goes down to \(darkest)")
            }
        }
    }
}
