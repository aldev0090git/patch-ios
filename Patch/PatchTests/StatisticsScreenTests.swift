import Foundation
import PatchCore
import Testing
@testable import Patch

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}

@Suite("Period selection")
struct PeriodSelectionTests {
    private let calendar = utcCalendar()

    @Test("Stepping back a month moves the window, not the kind")
    func steppingBackAMonth() {
        var selection = PeriodSelection(
            kind: .month,
            anchor: Date(timeIntervalSince1970: 1_760_000_000) // 2025-10-09
        )
        let before = selection.period.range(in: calendar)
        selection.step(by: -1, calendar: calendar)

        #expect(selection.kind == .month)
        #expect(selection.period.range(in: calendar).upperBound < before.lowerBound)
    }

    @Test("A custom range refuses to step — the user set both ends")
    func customDoesNotStep() {
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        var selection = PeriodSelection(kind: .custom, customStart: start, customEnd: start)
        let before = selection.period.range(in: calendar)
        selection.step(by: -1, calendar: calendar)

        #expect(selection.period.range(in: calendar) == before)
    }

    @Test("A backwards custom range is read in the order the calendar needs")
    func backwardsCustomRangeIsSorted() {
        let early = Date(timeIntervalSince1970: 1_760_000_000)
        let late = early.addingTimeInterval(5 * 86_400)
        let selection = PeriodSelection(kind: .custom, customStart: late, customEnd: early)
        let range = selection.period.range(in: calendar)

        #expect(range.lowerBound <= range.upperBound)
        #expect(calendar.isDate(range.lowerBound, inSameDayAs: early))
    }

    @Test("You cannot walk forward out of the window holding today")
    func cannotStepPastToday() {
        let selection = PeriodSelection(kind: .week, anchor: .now)
        #expect(selection.canStepForward(calendar: calendar) == false)
    }

    @Test("You can walk forward from a window in the past")
    func canStepForwardFromThePast() {
        let lastYear = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
        let selection = PeriodSelection(kind: .week, anchor: lastYear)
        #expect(selection.canStepForward(calendar: calendar))
    }
}

@Suite("Period titles")
struct PeriodFormatterTests {
    private let calendar = utcCalendar()
    private let locale = Locale(identifier: "en_GB")

    private func title(_ selection: PeriodSelection, asOf: Date = .now) -> String {
        PeriodFormatter.title(selection, calendar: calendar, locale: locale, asOf: asOf)
    }

    @Test("The window containing today is named, not dated")
    func relativeNames() {
        #expect(title(PeriodSelection(kind: .day, anchor: .now)) == "Today")
        #expect(title(PeriodSelection(kind: .week, anchor: .now)) == "This week")
        #expect(title(PeriodSelection(kind: .month, anchor: .now)) == "This month")
        #expect(title(PeriodSelection(kind: .year, anchor: .now)) == "This year")
    }

    @Test("The day before today is named too")
    func yesterdayIsNamed() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) ?? .now
        #expect(title(PeriodSelection(kind: .day, anchor: yesterday)) == "Yesterday")
    }

    @Test("An older window falls back to a date rather than a relative name")
    func olderWindowsAreDated() {
        let longAgo = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14
        let name = title(PeriodSelection(kind: .year, anchor: longAgo))

        #expect(name == "2023")
        #expect(name != "This year")
    }

    @Test("A past month in the current year drops the redundant year")
    func sameYearMonthHasNoYear() {
        let january = calendar.date(from: DateComponents(
            year: calendar.component(.year, from: .now), month: 1, day: 15
        )) ?? .now
        let name = title(PeriodSelection(kind: .month, anchor: january))

        // Skipped in January, when that month *is* this month.
        if name != "This month" {
            #expect(!name.contains("20"))
        }
    }

    @Test("A single-day custom range reads as one date, not a span")
    func singleDayCustomRange() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let name = title(PeriodSelection(kind: .custom, customStart: day, customEnd: day))
        #expect(!name.contains("–"))
    }
}

@Suite("Statistics model")
struct StatisticsModelTests {
    private let calendar = utcCalendar()

    /// A goal created well before the window, so no day is excluded for being
    /// older than the goal.
    private func goal(title: String = "Read", daysOld: Int = 90) -> Goal {
        Goal(
            title: title,
            measure: .minutes(20),
            createdAt: calendar.date(byAdding: .day, value: -daysOld, to: .now) ?? .now
        )
    }

    private func entry(_ goal: Goal, daysAgo: Int, amount: Decimal = 1200) -> Entry {
        Entry(
            goalID: goal.id,
            amount: amount,
            loggedAt: calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        )
    }

    @MainActor
    private func model(goals: [Goal], entries: [Entry]) -> StatisticsModel {
        let model = StatisticsModel(
            store: InMemoryGoalStore(goals: goals, entries: entries),
            calendar: calendar
        )
        model.load()
        model.selection = PeriodSelection(kind: .month, anchor: .now)
        return model
    }

    @MainActor
    @Test("A day that met its target counts as done")
    func completedDayCounts() {
        let read = goal()
        let model = model(goals: [read], entries: [entry(read, daysAgo: 1)])

        #expect(model.totals.completed == 1)
    }

    @MainActor
    @Test("A scheduled day with nothing logged counts as missed")
    func missedDayCounts() {
        let read = goal()
        let model = model(goals: [read], entries: [entry(read, daysAgo: 1)])

        // Two days back was scheduled and empty.
        #expect(model.totals.missed > 0)
        #expect(model.totals.scheduled == model.totals.completed + model.totals.missed)
    }

    @MainActor
    @Test("Archived goals are left out of the window")
    func archivedGoalsAreExcluded() {
        var read = goal()
        read.archivedAt = .now
        let model = model(goals: [read], entries: [entry(read, daysAgo: 1)])

        #expect(model.rows.isEmpty)
    }

    @MainActor
    @Test("A goal created after the window has nothing to report, not a zero")
    func goalNewerThanTheWindowIsDropped() {
        let fresh = Goal(title: "New", measure: .minutes(20), createdAt: .now)
        let model = model(goals: [fresh], entries: [])
        model.selection = PeriodSelection(
            kind: .month,
            anchor: calendar.date(byAdding: .month, value: -2, to: .now) ?? .now
        )

        #expect(model.rows.isEmpty)
        #expect(model.hasNothingToReport)
    }

    @MainActor
    @Test("Rows lead with the goal that needs attention")
    func rowsAreWorstFirst() {
        let strong = goal(title: "Strong")
        let weak = goal(title: "Weak")
        // 20 days logged against one, a single day against the other.
        let entries = (1...20).map { entry(strong, daysAgo: $0) } + [entry(weak, daysAgo: 1)]
        let model = model(goals: [strong, weak], entries: entries)

        #expect(model.rows.first?.goal.title == "Weak")
        #expect(model.rows.count == 2)
    }

    @MainActor
    @Test("A goal whose days are all still in play sorts below the settled ones")
    func unsettledGoalsSortLast() {
        // Created today, so nothing has settled: a rate of 0% would be
        // arithmetic, not a verdict, and must not lead the screen.
        let fresh = Goal(title: "Fresh", measure: .minutes(20), createdAt: .now)
        let old = goal(title: "Old")
        let model = model(goals: [fresh, old], entries: [])

        #expect(model.rows.count == 2)
        #expect(model.rows.first?.goal.title == "Old")
        #expect(model.rows.last?.goal.title == "Fresh")
        #expect(model.rows.last?.statistics.scheduledDays == 0)
    }

    @MainActor
    @Test("Totals ignore days that are still in play")
    func totalsSkipPendingDays() {
        let fresh = Goal(title: "Fresh", measure: .minutes(20), createdAt: .now)
        let model = model(goals: [fresh], entries: [])

        #expect(model.totals.scheduled == 0)
        #expect(model.totals.missed == 0)
        #expect(model.hasNothingToReport)
    }

    @MainActor
    @Test("A goal with a long-run target reports progress toward it")
    func overallProgressIsReported() {
        let saving = Goal(
            title: "Save",
            measure: .money(100),
            cumulativeTarget: 1000,
            createdAt: calendar.date(byAdding: .day, value: -30, to: .now) ?? .now
        )
        let logged = (1...3).compactMap { back -> Entry? in
            guard let date = calendar.date(byAdding: .day, value: -back, to: .now) else { return nil }
            return Entry(goalID: saving.id, amount: 100, loggedAt: date)
        }
        let model = model(goals: [saving], entries: logged)

        let overall = model.rows.first?.overall
        #expect(overall?.total == 300)
        #expect(overall?.target == 1000)
        #expect(overall?.isReached == false)
    }

    @MainActor
    @Test("A goal without a long-run target reports none")
    func noOverallWhenNotAsked() {
        let read = goal()
        let model = model(goals: [read], entries: [entry(read, daysAgo: 1)])

        #expect(model.rows.first?.overall == nil)
    }

    @MainActor
    @Test("The long-run total is not clipped to the window on screen")
    func overallIgnoresTheWindow() {
        // "Save 100 000" means since the beginning, not since Monday.
        let saving = Goal(
            title: "Save",
            measure: .money(100),
            cumulativeTarget: 1000,
            createdAt: calendar.date(byAdding: .day, value: -120, to: .now) ?? .now
        )
        let old = calendar.date(byAdding: .day, value: -100, to: .now) ?? .now
        let model = model(goals: [saving], entries: [Entry(goalID: saving.id, amount: 400, loggedAt: old)])
        model.selection = PeriodSelection(kind: .week, anchor: .now)

        #expect(model.rows.first?.overall?.total == 400)
    }

    @MainActor
    @Test("Completion rate is done over settled days, never over the calendar")
    func completionRateIgnoresUnsettledDays() {
        let read = goal()
        let model = model(goals: [read], entries: [entry(read, daysAgo: 1)])
        let totals = model.totals

        #expect(model.completionRate == Double(totals.completed) / Double(totals.scheduled))
        #expect(model.completionRate <= 1)
    }

    @MainActor
    @Test("A store that refuses to load surfaces the failure instead of showing zeroes")
    func loadFailureIsSurfaced() {
        let model = StatisticsModel(store: FailingStatisticsStore(), calendar: calendar)
        model.load()

        #expect(model.failure != nil)
        #expect(model.rows.isEmpty)
    }
}

@MainActor
private final class FailingStatisticsStore: GoalStore {
    struct Nope: Error, LocalizedError {
        var errorDescription: String? { "disk on fire" }
    }

    func loadGoals() throws -> [Goal] { throw Nope() }
    func loadEntries() throws -> [Entry] { throw Nope() }
    func save(_ goal: Goal) throws { throw Nope() }
    func log(_ entry: Entry) throws { throw Nope() }
    func deleteEntries(ids: [Entry.ID]) throws { throw Nope() }
}
