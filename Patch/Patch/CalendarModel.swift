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

    /// Whether the day on screen can still be written to.
    ///
    /// Only the future is closed. There is deliberately no limit on how far
    /// back you may reach: the most-upvoted complaint about every habit
    /// tracker in this category is being unable to fix a day you forgot, and
    /// with no leaderboard and no server there is nobody to cheat but
    /// yourself.
    var isSelectedDayWritable: Bool {
        guard let selectedDay else { return false }
        return calendar.startOfDay(for: selectedDay) <= calendar.startOfDay(for: .now)
    }

    /// Whether this goal can be logged against on this day.
    ///
    /// Checked here rather than only in the view. A view can be wrong, and an
    /// entry written to a day the goal was not scheduled for would count
    /// toward totals while appearing on no screen that could remove it again.
    func canLog(_ goal: Goal, on date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard day <= calendar.startOfDay(for: .now) else { return false }
        guard !goal.isArchived else { return false }
        guard calendar.startOfDay(for: goal.createdAt) <= day else { return false }
        return goal.schedule.isScheduled(on: day, calendar: calendar)
    }

    func progress(for goal: Goal, on date: Date) -> DayProgress {
        progress.progress(for: goal, entries: entries, on: date)
    }

    func hasLogged(_ goal: Goal, on date: Date) -> Bool {
        entries.contains { $0.goalID == goal.id && calendar.isDate($0.loggedAt, inSameDayAs: date) }
    }

    // MARK: - Writing to a past day

    func log(_ amount: Decimal, for goal: Goal, on date: Date) {
        guard canLog(goal, on: date) else { return }
        let entry = Entry(goalID: goal.id, amount: amount, loggedAt: timestamp(for: date))
        do {
            try store.log(entry)
            entries.append(entry)
            publishToWidget()
        } catch {
            failure = String(localized: "Couldn't save that. \(error.localizedDescription)")
        }
    }

    /// Removes everything logged for this goal on this day.
    func clearDay(for goal: Goal, on date: Date) {
        let doomed = entries.filter {
            $0.goalID == goal.id && calendar.isDate($0.loggedAt, inSameDayAs: date)
        }
        guard !doomed.isEmpty else { return }

        do {
            try store.deleteEntries(ids: doomed.map(\.id))
            let ids = Set(doomed.map(\.id))
            entries.removeAll { ids.contains($0.id) }
            publishToWidget()
        } catch {
            failure = String(localized: "Couldn't reset that. \(error.localizedDescription)")
        }
    }

    /// Logging a past day can change today's picture — clearing today from
    /// the Calendar, for one — so the home screen follows these writes too.
    private func publishToWidget() {
        WidgetPublisher.publish(goals: goals, entries: entries, calendar: calendar)
    }

    /// Midday, not midnight.
    ///
    /// Both land on the right day where they are written, but an entry stamped
    /// at 00:00 and read back from a different time zone can fall into the day
    /// before. Midday leaves twelve hours of slack either side, and the one
    /// thing a backdated entry must never do is move to another day.
    private func timestamp(for date: Date) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)
            ?? calendar.startOfDay(for: date)
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
