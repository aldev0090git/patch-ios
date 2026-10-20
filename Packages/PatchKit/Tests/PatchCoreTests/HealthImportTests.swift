import Foundation
import Testing
@testable import PatchCore

@Suite("Importing from Apple Health")
struct HealthImportTests {
    private let calendar = fixedCalendar()

    private func stepGoal(
        target: Int = 10_000,
        createdAt: Date = day(2026, 3, 1),
        schedule: Schedule = .daily,
        source: HealthSource? = .steps,
        archivedAt: Date? = nil
    ) -> Goal {
        Goal(
            title: "Steps",
            measure: .steps(target),
            schedule: schedule,
            createdAt: createdAt,
            healthSource: source,
            archivedAt: archivedAt
        )
    }

    private func plan(
        _ totals: [Date: Decimal],
        into goal: Goal,
        existing: [Entry] = [],
        now: Date = day(2026, 3, 10)
    ) -> [Entry] {
        HealthImportPlanner.entries(
            importing: totals,
            into: goal,
            existing: existing,
            now: now,
            calendar: calendar
        )
    }

    // MARK: - The basic contract

    @Test("A day Health knows about and Patch does not becomes one entry")
    func firstImport() {
        let goal = stepGoal()
        let entries = plan([day(2026, 3, 10): 7432], into: goal)

        #expect(entries.count == 1)
        #expect(entries.first?.amount == 7432)
        #expect(entries.first?.goalID == goal.id)
        #expect(entries.first?.source == .health)
    }

    @Test("A goal not linked to Health imports nothing, however much Health knows")
    func unlinkedGoalIsLeftAlone() {
        #expect(plan([day(2026, 3, 10): 7432], into: stepGoal(source: nil)).isEmpty)
    }

    @Test("An archived goal stops importing")
    func archivedGoalIsLeftAlone() {
        let goal = stepGoal(archivedAt: day(2026, 3, 5))
        #expect(plan([day(2026, 3, 10): 7432], into: goal).isEmpty)
    }

    // MARK: - Topping up, which is the whole reason entries carry a source

    @Test("Health's total climbing through the day adds only the difference")
    func secondImportAddsTheDifference() {
        let goal = stepGoal()
        let morning = plan([day(2026, 3, 10): 2000], into: goal)
        let midday = plan([day(2026, 3, 10): 5000], into: goal, existing: morning)
        let evening = plan([day(2026, 3, 10): 7432], into: goal, existing: morning + midday)

        #expect(midday.first?.amount == 3000)
        #expect(evening.first?.amount == 2432)
        // The point of all of it: the day totals what Health says, once.
        #expect((morning + midday + evening).reduce(Decimal.zero) { $0 + $1.amount } == 7432)
    }

    @Test("Re-running with nothing new writes nothing")
    func idempotentWhenNothingChanged() {
        let goal = stepGoal()
        let first = plan([day(2026, 3, 10): 7432], into: goal)
        #expect(plan([day(2026, 3, 10): 7432], into: goal, existing: first).isEmpty)
    }

    @Test("Several readings within one day are one day's total, not several")
    func instantsWithinADayCollapse() {
        // A caller handing back raw sample instants must not produce an entry
        // per instant, each cancelling the last one's delta out.
        let goal = stepGoal()
        let entries = plan(
            [day(2026, 3, 10, hour: 9): 2000, day(2026, 3, 10, hour: 18): 5432],
            into: goal
        )

        #expect(entries.count == 1)
        #expect(entries.first?.amount == 7432)
    }

    @Test("A tap the user made by hand is not swallowed by the next refresh")
    func manualEntriesSurvive() {
        // Walked on a treadmill the phone was not in, logged it, then Health
        // reports the day separately. Both happened; both count.
        let goal = stepGoal()
        let imported = plan([day(2026, 3, 10): 4000], into: goal)
        let byHand = Entry(goalID: goal.id, amount: 3000, loggedAt: day(2026, 3, 10), source: .manual)

        let next = plan([day(2026, 3, 10): 6000], into: goal, existing: imported + [byHand])

        #expect(next.first?.amount == 2000, "The manual 3 000 was treated as imported")
    }

    @Test("Deleting a workout in Health takes the day back down")
    func totalsCanFall() {
        let goal = stepGoal()
        let imported = plan([day(2026, 3, 10): 7432], into: goal)
        let corrected = plan([day(2026, 3, 10): 3000], into: goal, existing: imported)

        #expect(corrected.first?.amount == -4432)
        #expect((imported + corrected).reduce(Decimal.zero) { $0 + $1.amount } == 3000)
    }

    // MARK: - Days it must refuse

    @Test("Days before the goal existed are not backfilled")
    func doesNotPredateTheGoal() {
        let goal = stepGoal(createdAt: day(2026, 3, 8))
        let entries = plan(
            [day(2026, 3, 7): 9000, day(2026, 3, 8): 8000, day(2026, 3, 9): 7000],
            into: goal
        )

        #expect(entries.count == 2)
        #expect(!entries.contains { calendar.isDate($0.loggedAt, inSameDayAs: day(2026, 3, 7)) })
    }

    @Test("A goal created partway through a day still imports that day")
    func importsTheDayOfCreation() {
        // Created at 6pm, having already walked. Comparing instants rather
        // than days here would throw the day away.
        let goal = stepGoal(createdAt: day(2026, 3, 10, hour: 18))
        #expect(plan([day(2026, 3, 10, hour: 9): 7432], into: goal).count == 1)
    }

    @Test("Tomorrow is not imported, whatever Health claims")
    func refusesTheFuture() {
        let goal = stepGoal()
        let entries = plan(
            [day(2026, 3, 10): 7000, day(2026, 3, 11): 1],
            into: goal,
            now: day(2026, 3, 10)
        )

        #expect(entries.count == 1)
        #expect(calendar.isDate(entries[0].loggedAt, inSameDayAs: day(2026, 3, 10)))
    }

    @Test("A weekday goal does not import at the weekend")
    func respectsTheSchedule() {
        // 7 March 2026 is a Saturday, 9 March a Monday.
        let goal = stepGoal(createdAt: day(2026, 3, 1), schedule: .weekdays)
        let entries = plan([day(2026, 3, 7): 9000, day(2026, 3, 9): 8000], into: goal)

        #expect(entries.count == 1)
        #expect(calendar.isDate(entries[0].loggedAt, inSameDayAs: day(2026, 3, 9)))
    }

    @Test("A source that cannot fill the goal's measure writes nothing")
    func refusesAMismatchedKind() {
        // Metres written into a goal counting repetitions would read as a
        // target smashed thousands of times over.
        let goal = Goal(
            title: "Push-ups",
            measure: .times(20),
            createdAt: day(2026, 3, 1),
            healthSource: .walkingRunningDistance
        )
        #expect(plan([day(2026, 3, 10): 5000], into: goal).isEmpty)
    }

    @Test("Entries belonging to other goals are ignored, not counted")
    func otherGoalsDoNotCount() {
        let goal = stepGoal()
        let somebodyElses = Entry(
            goalID: UUID(),
            amount: 5000,
            loggedAt: day(2026, 3, 10),
            source: .health
        )
        #expect(plan([day(2026, 3, 10): 7432], into: goal, existing: [somebodyElses])
            .first?.amount == 7432)
    }

    // MARK: - Timestamps

    @Test("Today is stamped now; an earlier day is stamped midday")
    func timestamps() {
        let now = day(2026, 3, 10, hour: 21)
        let goal = stepGoal()
        let entries = plan([day(2026, 3, 9): 5000, day(2026, 3, 10): 7000], into: goal, now: now)

        #expect(entries[0].loggedAt == day(2026, 3, 9, hour: 12), "A past day must sit at midday")
        #expect(entries[1].loggedAt == now)
    }

    // MARK: - The source itself

    @Test("Every source names a measure kind whose canonical unit is Health's own")
    func unitsLineUp() {
        #expect(HealthSource.steps.measureKind == .count)
        #expect(HealthSource.walkingRunningDistance.measureKind == .distance)
        #expect(HealthSource.exerciseMinutes.measureKind == .duration)
    }

    @Test("Only kinds a phone can actually measure offer a source")
    func compatibility() {
        #expect(HealthSource.compatible(with: .count) == [.steps])
        #expect(HealthSource.compatible(with: .distance) == [.walkingRunningDistance])
        #expect(HealthSource.compatible(with: .duration) == [.exerciseMinutes])
        #expect(HealthSource.compatible(with: .volume).isEmpty)
        #expect(HealthSource.compatible(with: .currency).isEmpty)
    }

    @Test("An entry exported before Health existed reads back as manual")
    func schemaOneEntriesDecodeAsManual() throws {
        let json = """
        {"id":"\(UUID().uuidString)","goalID":"\(UUID().uuidString)",\
        "amount":42,"loggedAt":"2026-03-10T12:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entry = try decoder.decode(Entry.self, from: Data(json.utf8))

        #expect(entry.source == .manual)
    }
}
