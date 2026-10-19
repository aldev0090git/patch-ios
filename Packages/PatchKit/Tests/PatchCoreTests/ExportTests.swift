import Foundation
import Testing
@testable import PatchCore

@Suite("Exporting your data")
struct ExportTests {
    private let calendar = fixedCalendar()

    private func goal(
        title: String = "Read",
        measure: Measure = .minutes(20)
    ) -> Goal {
        Goal(title: title, measure: measure, createdAt: day(2026, 1, 1))
    }

    // MARK: - JSON

    @Test("The archive reads back exactly what went in")
    func jsonRoundTrips() throws {
        // The whole promise of the backup: no account and no server is only
        // reasonable if the data can come home again.
        let read = goal()
        let water = Goal(title: "Water", measure: .millilitres(2000), createdAt: day(2026, 1, 2))
        let entries = [
            Entry(goalID: read.id, amount: 600, loggedAt: day(2026, 1, 3)),
            Entry(goalID: water.id, amount: 500, loggedAt: day(2026, 1, 4))
        ]

        let document = GoalExport.json(goals: [read, water], entries: entries)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(GoalExport.Archive.self, from: document.data)

        #expect(archive.goals == [read, water])
        #expect(Set(archive.entries) == Set(entries))
        #expect(archive.schemaVersion == GoalExport.schemaVersion)
    }

    @Test("An archived goal is still in the backup")
    func archivedGoalsAreIncluded() throws {
        // Archiving hides a goal from Today. It does not mean the user has
        // thrown its history away, and a backup that quietly dropped it would
        // lose months of record.
        var abandoned = goal(title: "Gym")
        abandoned.archivedAt = day(2026, 2, 1)

        let document = GoalExport.json(goals: [abandoned], entries: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(GoalExport.Archive.self, from: document.data)

        #expect(archive.goals.first?.isArchived == true)
    }

    @Test("Two exports of the same data are the same file")
    func exportIsStable() {
        let read = goal()
        let entries = [Entry(goalID: read.id, amount: 600, loggedAt: day(2026, 1, 3))]
        let when = day(2026, 3, 1)

        let first = GoalExport.json(goals: [read], entries: entries, exportedAt: when)
        let second = GoalExport.json(goals: [read], entries: entries, exportedAt: when)

        // A backup that differs byte for byte every time cannot be diffed or
        // deduplicated, which is most of what people do with backups.
        #expect(first.data == second.data)
    }

    @Test("An empty app still exports a valid file")
    func emptyExportIsValid() throws {
        let document = GoalExport.json(goals: [], entries: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(GoalExport.Archive.self, from: document.data)

        #expect(archive.goals.isEmpty)
        #expect(archive.entries.isEmpty)
    }

    // MARK: - CSV

    @Test("One row per goal per day, with that day's total")
    func csvSummarisesByDay() {
        let read = goal()
        let entries = [
            Entry(goalID: read.id, amount: 600, loggedAt: day(2026, 1, 3)),
            Entry(goalID: read.id, amount: 600, loggedAt: day(2026, 1, 3)),
            Entry(goalID: read.id, amount: 300, loggedAt: day(2026, 1, 4))
        ]

        let lines = GoalExport.csv(goals: [read], entries: entries, calendar: calendar)
            .text
            .split(separator: "\n")

        #expect(lines.first == "date,goal,amount,unit,target,achieved")
        #expect(lines.count == 3)
        // Two taps of ten minutes is one fact to a person reading a
        // spreadsheet, not two rows to be added up.
        #expect(lines[1] == "2026-01-03,Read,1200,s,1200,yes")
        #expect(lines[2] == "2026-01-04,Read,300,s,1200,no")
    }

    @Test("A goal named with a comma does not tear the file in half")
    func csvEscapesSeparators() {
        let awkward = goal(title: #"Read "War and Peace", slowly"#)
        let entries = [Entry(goalID: awkward.id, amount: 1200, loggedAt: day(2026, 1, 3))]

        let row = GoalExport.csv(goals: [awkward], entries: entries, calendar: calendar)
            .text
            .split(separator: "\n")[1]

        // Quoted, with inner quotes doubled — the rule every spreadsheet reads.
        #expect(row.contains(#""Read ""War and Peace"", slowly""#))
        #expect(row.hasPrefix("2026-01-03,"))
    }

    @Test("A plain name is not needlessly quoted")
    func csvLeavesSimpleNamesAlone() {
        let read = goal()
        let entries = [Entry(goalID: read.id, amount: 1200, loggedAt: day(2026, 1, 3))]

        let row = GoalExport.csv(goals: [read], entries: entries, calendar: calendar)
            .text
            .split(separator: "\n")[1]

        #expect(row.contains(",Read,"))
    }

    @Test("A money goal names its currency, not \"major unit\"")
    func csvNamesTheCurrency() {
        let saving = Goal(
            title: "Save",
            measure: .money(100, currencyCode: "UAH"),
            createdAt: day(2026, 1, 1)
        )
        let entries = [Entry(goalID: saving.id, amount: 100, loggedAt: day(2026, 1, 3))]

        let row = GoalExport.csv(goals: [saving], entries: entries, calendar: calendar)
            .text
            .split(separator: "\n")[1]

        #expect(row.contains(",UAH,"))
    }

    @Test("A day judged against the target it had then, not today's")
    func csvUsesTheTargetInForce() {
        // The same rule the rest of the app follows: raising a target must not
        // turn finished days behind it into failures, in the export either.
        var read = goal()
        read = read.withTarget(3600, changedOn: day(2026, 2, 1), calendar: calendar)
        let entries = [Entry(goalID: read.id, amount: 1200, loggedAt: day(2026, 1, 3))]

        let row = GoalExport.csv(goals: [read], entries: entries, calendar: calendar)
            .text
            .split(separator: "\n")[1]

        #expect(row.hasSuffix(",1200,yes"))
    }

    @Test("The filename says when it was taken")
    func filenameCarriesTheDate() {
        let when = day(2026, 3, 9)
        #expect(GoalExport.json(goals: [], entries: [], exportedAt: when).filename
            == "patch-2026-03-09.json")
        #expect(GoalExport.csv(goals: [], entries: [], exportedAt: when).filename
            == "patch-2026-03-09.csv")
    }
}
