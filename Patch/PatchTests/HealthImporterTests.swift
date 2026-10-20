import Foundation
import PatchCore
import Testing
@testable import Patch

/// Covers the orchestration only. *What* to write is decided by
/// `HealthImportPlanner` and tested exhaustively in `PatchCoreTests`; this
/// suite is about how many times Health is asked, and what happens when it
/// refuses.
/// At file scope rather than nested in the fake: SwiftLint allows one level
/// of nesting and the fake is already using it.
private struct UnreadableHealth: Error {}

@Suite("Health import")
@MainActor
struct HealthImporterTests {
    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar().date(from: DateComponents(year: year, month: month, day: day, hour: hour))
            ?? .distantPast
    }

    /// Records what it was asked and answers from a script.
    private final class FakeHealth: HealthReading {
        var isAvailable = true
        var totals: [HealthSource: [Date: Decimal]] = [:]
        var failing: Set<HealthSource> = []
        private(set) var asked: [HealthSource] = []
        private(set) var ranges: [(start: Date, end: Date)] = []

        func dailyTotals(
            for source: HealthSource,
            from start: Date,
            to end: Date,
            calendar: Calendar
        ) async throws -> [Date: Decimal] {
            asked.append(source)
            ranges.append((start, end))
            if failing.contains(source) { throw UnreadableHealth() }
            return totals[source] ?? [:]
        }
    }

    private func goal(
        _ title: String,
        measure: Measure,
        source: HealthSource?,
        archived: Bool = false
    ) -> Goal {
        Goal(
            title: title,
            measure: measure,
            createdAt: date(2026, 3, 1),
            healthSource: source,
            archivedAt: archived ? date(2026, 3, 5) : nil
        )
    }

    @Test("Two goals reading steps ask Health once, not twice")
    func oneQueryPerSource() async {
        let health = FakeHealth()
        health.totals[.steps] = [date(2026, 3, 10): 7432]
        let goals = [
            goal("Steps", measure: .steps(10_000), source: .steps),
            goal("Move more", measure: .steps(5000), source: .steps)
        ]

        let pending = await HealthImporter(reader: health, calendar: calendar())
            .pendingEntries(goals: goals, entries: [], now: date(2026, 3, 10))

        #expect(health.asked == [.steps], "Health was asked once per goal, not once per source")
        #expect(pending.count == 2, "Both goals should be filled from the one answer")
        #expect(Set(pending.map(\.goalID)) == Set(goals.map(\.id)))
    }

    @Test("A source Health refuses does not take the other sources down with it")
    func oneFailureIsIsolated() async {
        let health = FakeHealth()
        health.failing = [.steps]
        health.totals[.walkingRunningDistance] = [date(2026, 3, 10): 5000]
        let goals = [
            goal("Steps", measure: .steps(10_000), source: .steps),
            goal("Walk", measure: Measure(kind: .distance, dailyTarget: 5000),
                 source: .walkingRunningDistance)
        ]

        let pending = await HealthImporter(reader: health, calendar: calendar())
            .pendingEntries(goals: goals, entries: [], now: date(2026, 3, 10))

        #expect(pending.count == 1)
        #expect(pending.first?.amount == 5000)
    }

    @Test("Only the sources actually in use are queried")
    func unusedSourcesAreNotQueried() async {
        let health = FakeHealth()
        let goals = [goal("Steps", measure: .steps(10_000), source: .steps)]

        _ = await HealthImporter(reader: health, calendar: calendar())
            .pendingEntries(goals: goals, entries: [], now: date(2026, 3, 10))

        #expect(health.asked == [.steps])
    }

    @Test("Nothing is asked when no goal is linked to Health")
    func noLinkedGoalsAsksNothing() async {
        let health = FakeHealth()
        let goals = [goal("Push-ups", measure: .times(20), source: nil)]

        let pending = await HealthImporter(reader: health, calendar: calendar())
            .pendingEntries(goals: goals, entries: [], now: date(2026, 3, 10))

        #expect(health.asked.isEmpty, "Health was woken up for an app that does not use it")
        #expect(pending.isEmpty)
    }

    @Test("An archived goal is not kept up to date")
    func archivedGoalsAreNotQueried() async {
        let health = FakeHealth()
        let goals = [goal("Steps", measure: .steps(10_000), source: .steps, archived: true)]

        _ = await HealthImporter(reader: health, calendar: calendar())
            .pendingEntries(goals: goals, entries: [], now: date(2026, 3, 10))

        #expect(health.asked.isEmpty)
    }

    @Test("Where there is no Health at all, nothing is asked and nothing fails")
    func unavailableHealthIsSilent() async {
        let health = FakeHealth()
        health.isAvailable = false
        let goals = [goal("Steps", measure: .steps(10_000), source: .steps)]

        let pending = await HealthImporter(reader: health, calendar: calendar())
            .pendingEntries(goals: goals, entries: [], now: date(2026, 3, 10))

        #expect(health.asked.isEmpty)
        #expect(pending.isEmpty)
    }

    @Test("The window reaches a week back and takes in all of today")
    func queryWindow() async throws {
        let health = FakeHealth()
        let now = date(2026, 3, 10, hour: 9)
        let goals = [goal("Steps", measure: .steps(10_000), source: .steps)]

        _ = await HealthImporter(reader: health, calendar: calendar())
            .pendingEntries(goals: goals, entries: [], now: now)

        let range = try #require(health.ranges.first)
        #expect(range.start == date(2026, 3, 4, hour: 0), "A week back, inclusive of today")
        // Not `now`: samples recorded later today would fall outside a window
        // that ended at the moment the app happened to be opened.
        #expect(range.end == date(2026, 3, 11, hour: 0), "The window must cover the rest of today")
    }

    @Test("A day already imported in full produces nothing on the next run")
    func idempotentAcrossRuns() async {
        let health = FakeHealth()
        health.totals[.steps] = [date(2026, 3, 10): 7432]
        let goals = [goal("Steps", measure: .steps(10_000), source: .steps)]
        let importer = HealthImporter(reader: health, calendar: calendar())

        let first = await importer.pendingEntries(goals: goals, entries: [], now: date(2026, 3, 10))
        let second = await importer.pendingEntries(
            goals: goals, entries: first, now: date(2026, 3, 10)
        )

        #expect(first.count == 1)
        #expect(second.isEmpty)
    }
}
