import Foundation
import Observation
import PatchCore

/// The window's settled days, added up across every goal on screen.
struct Totals: Hashable {
    var completed = 0
    var missed = 0
    var scheduled = 0

    var rate: Double {
        scheduled > 0 ? Double(completed) / Double(scheduled) : 0
    }
}

/// One row of the statistics screen: a goal and how it did over the window.
struct GoalStatistics: Identifiable, Hashable {
    let goal: Goal
    let statistics: PeriodStatistics

    var id: Goal.ID { goal.id }
}

/// State for the statistics screen.
///
/// Read-only: nothing here writes. It reloads from the store when the screen
/// appears rather than sharing `TodayModel`'s arrays, so logging something on
/// Today and switching tabs shows the new number without the two screens
/// having to know about each other.
@MainActor
@Observable
final class StatisticsModel {
    private let store: GoalStore
    private let calendar: Calendar
    private let calculator: StatisticsCalculator

    private(set) var goals: [Goal] = []
    private(set) var entries: [Entry] = []

    var selection = PeriodSelection()
    var failure: String?

    init(store: GoalStore, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
        self.calculator = StatisticsCalculator(calendar: calendar)
    }

    func load() {
        do {
            goals = try store.loadGoals()
            entries = try store.loadEntries()
        } catch {
            failure = String(localized: "Couldn't load your statistics. \(error.localizedDescription)")
        }
    }

    /// Archived goals are left out, matching what Today shows. Their history is
    /// still on disk — this is a display choice, not a deletion.
    var activeGoals: [Goal] {
        goals.filter { !$0.isArchived }
    }

    /// Goals with anything to say about this window, worst first.
    ///
    /// Goals whose days are all still in play sort to the bottom rather than
    /// the top: they have a rate of zero arithmetically, but nothing has gone
    /// wrong yet, and leading the screen with them would read as four
    /// failures. A goal the window never scheduled at all is dropped.
    var rows: [GoalStatistics] {
        activeGoals
            .map { GoalStatistics(goal: $0, statistics: statistics(for: $0)) }
            .filter { $0.statistics.scheduledDays > 0 || $0.statistics.hasPendingToday }
            .sorted { lhs, rhs in
                let lhsSettled = lhs.statistics.scheduledDays > 0
                let rhsSettled = rhs.statistics.scheduledDays > 0
                if lhsSettled != rhsSettled { return lhsSettled }
                if lhsSettled, lhs.statistics.completionRate != rhs.statistics.completionRate {
                    return lhs.statistics.completionRate < rhs.statistics.completionRate
                }
                return lhs.goal.title < rhs.goal.title
            }
    }

    func statistics(for goal: Goal) -> PeriodStatistics {
        calculator.statistics(
            for: goal,
            entries: entries,
            period: selection.period,
            asOf: .now
        )
    }

    // MARK: - The window as a whole

    /// Every goal's settled days added together. Days still in play are in
    /// neither count, so `completed + missed` is always the denominator.
    var totals: Totals {
        rows.reduce(into: Totals()) { result, row in
            result.completed += row.statistics.completedDays
            result.missed += row.statistics.missedDays
            result.scheduled += row.statistics.scheduledDays
        }
    }

    var completionRate: Double { totals.rate }

    /// True when the window has no settled days at all — a brand new goal, or a
    /// window entirely in the future. The screen says so instead of showing 0%.
    var hasNothingToReport: Bool {
        totals.scheduled == 0
    }

    // MARK: - Moving between windows

    func step(by delta: Int) {
        selection.step(by: delta, calendar: calendar)
    }

    var canStepForward: Bool {
        selection.canStepForward(calendar: calendar)
    }

    var periodTitle: String {
        PeriodFormatter.title(selection, calendar: calendar)
    }
}
