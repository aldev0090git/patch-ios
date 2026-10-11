import Foundation
import Observation
import PatchCore

/// One cell of the month grid.
struct CalendarDay: Identifiable, Hashable {
    let date: Date
    let summary: DaySummary
    /// False for the leading and trailing days borrowed from neighbouring
    /// months to square off the grid.
    let isInMonth: Bool
    let isToday: Bool
    /// Nothing has happened yet, so the cell shows no verdict.
    let isFuture: Bool

    var id: Date { date }

    var fraction: Double { summary.fraction }
    var isComplete: Bool { summary.scheduled > 0 && summary.remaining == 0 }
    /// A day with no goals scheduled is blank rather than failed.
    var hasAnything: Bool { summary.scheduled > 0 }
}

/// One goal's standing on the selected day. `DayProgress` does not carry the
/// goal it describes, so the pair is kept together here.
struct DayGoalProgress: Identifiable, Hashable {
    let goal: Goal
    let progress: DayProgress

    var id: Goal.ID { goal.id }
}

/// State for the calendar screen.
@MainActor
@Observable
final class CalendarModel {
    private let store: GoalStore
    private let calendar: Calendar
    private let statistics: StatisticsCalculator
    private let progress: ProgressCalculator

    private(set) var goals: [Goal] = []
    private(set) var entries: [Entry] = []

    /// Any date inside the month on screen.
    var month: Date = .now
    var selectedDay: Date?
    var failure: String?

    init(store: GoalStore, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
        self.statistics = StatisticsCalculator(calendar: calendar)
        self.progress = ProgressCalculator(calendar: calendar)
    }

    func load() {
        do {
            goals = try store.loadGoals()
            entries = try store.loadEntries()
        } catch {
            failure = String(localized: "Couldn't load your calendar. \(error.localizedDescription)")
        }
    }

    // MARK: - The grid

    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        // Rotated so the row starts on whichever day this locale starts on:
        // Monday here, Sunday in the US, Saturday in much of the Middle East.
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Whole weeks covering the month, so the grid is always rectangular.
    var days: [CalendarDay] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let monthStart = calendar.startOfDay(for: interval.start)
        let monthEnd = calendar.startOfDay(for: interval.end.addingTimeInterval(-1))

        let leading = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) else {
            return []
        }

        let trailing = 6 - (calendar.component(.weekday, from: monthEnd) - calendar.firstWeekday + 7) % 7
        guard let gridEnd = calendar.date(byAdding: .day, value: trailing, to: monthEnd) else {
            return []
        }

        let today = calendar.startOfDay(for: .now)
        let summaries = statistics.summaries(for: goals, entries: entries, in: gridStart...gridEnd)

        return summaries.map { summary in
            CalendarDay(
                date: summary.date,
                summary: summary,
                isInMonth: calendar.isDate(summary.date, equalTo: month, toGranularity: .month),
                isToday: summary.date == today,
                isFuture: summary.date > today
            )
        }
    }

    // MARK: - The selected day

    /// Every goal that was due on the selected day, with how it went.
    ///
    /// Goals created after that day are left out: they were not missed, they
    /// did not exist.
    var selectedDayProgress: [DayGoalProgress] {
        guard let selectedDay else { return [] }
        return goals
            .filter { !$0.isArchived && calendar.startOfDay(for: $0.createdAt) <= selectedDay }
            .map {
                DayGoalProgress(
                    goal: $0,
                    progress: progress.progress(for: $0, entries: entries, on: selectedDay)
                )
            }
            .filter(\.progress.isScheduled)
    }

    // MARK: - Moving between months

    func step(by delta: Int) {
        guard let moved = calendar.date(byAdding: .month, value: delta, to: month) else { return }
        month = moved
        // The selection belongs to the month it was made in; carrying it
        // forward would highlight an arbitrary day in the new one.
        selectedDay = nil
    }

    /// False once the month on screen contains today.
    var canStepForward: Bool {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return false }
        return interval.end <= .now
    }

    var monthTitle: String {
        let sameYear = calendar.component(.year, from: month)
            == calendar.component(.year, from: .now)
        return month.formatted(
            sameYear ? .dateTime.month(.wide) : .dateTime.month(.wide).year()
        )
    }
}
