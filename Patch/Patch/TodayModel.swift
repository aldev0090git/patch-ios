import Foundation
import Observation
import PatchCore

/// State for the Today screen.
///
/// Holds goals and entries in memory and writes every change straight through
/// to the store, so what is on screen and what is on disk never drift. At this
/// size that is simpler and more obviously correct than reconciling a cache.
@MainActor
@Observable
final class TodayModel {
    private let store: GoalStore
    private let calendar: Calendar
    private let calculator: ProgressCalculator
    private let streaks: StreakCalculator

    private(set) var goals: [Goal] = []
    private(set) var entries: [Entry] = []

    /// Set when the store refuses a read or a write. Surfaced rather than
    /// swallowed: silently losing a logged entry is worse than an alert.
    var failure: String?

    init(store: GoalStore, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
        self.calculator = ProgressCalculator(calendar: calendar)
        self.streaks = StreakCalculator(calendar: calendar)
    }

    // MARK: - Reading

    var todaysGoals: [Goal] {
        goals.filter {
            !$0.isArchived && $0.schedule.isScheduled(on: .now, calendar: calendar)
        }
    }

    var todaysProgress: [DayProgress] {
        todaysGoals.map(progress(for:))
    }

    func progress(for goal: Goal) -> DayProgress {
        calculator.progress(for: goal, entries: entries, on: .now)
    }

    /// How many days in a row this goal has been met.
    ///
    /// Unscheduled days are skipped rather than breaking the run, and an
    /// unfinished today measures from yesterday — both rules live in
    /// `StreakCalculator` and are tested there.
    func streak(for goal: Goal) -> Int {
        streaks.currentStreak(for: goal, entries: entries)
    }

    func hasLoggedToday(_ goal: Goal) -> Bool {
        entries.contains { $0.goalID == goal.id && calendar.isDateInToday($0.loggedAt) }
    }

    // MARK: - Writing

    func load() {
        do {
            goals = try store.loadGoals()
            entries = try store.loadEntries()
        } catch {
            failure = String(localized: "Couldn't load your goals. \(error.localizedDescription)")
        }
    }

    func log(_ amount: Decimal, for goal: Goal) {
        let entry = Entry(goalID: goal.id, amount: amount)
        do {
            try store.log(entry)
            entries.append(entry)
        } catch {
            failure = String(localized: "Couldn't save that. \(error.localizedDescription)")
        }
    }

    /// Removes everything logged today for this goal.
    func resetToday(for goal: Goal) {
        let doomed = entries.filter {
            $0.goalID == goal.id && calendar.isDateInToday($0.loggedAt)
        }
        guard !doomed.isEmpty else { return }

        do {
            try store.deleteEntries(ids: doomed.map(\.id))
            let ids = Set(doomed.map(\.id))
            entries.removeAll { ids.contains($0.id) }
        } catch {
            failure = String(localized: "Couldn't reset that. \(error.localizedDescription)")
        }
    }

    /// Creates the goal, or updates the stored one with the same id.
    func save(_ goal: Goal) {
        do {
            try store.save(goal)
            goals = try store.loadGoals()
        } catch {
            failure = String(localized: "Couldn't save that. \(error.localizedDescription)")
        }
    }

    /// Archives rather than deletes.
    ///
    /// The goal stops appearing in Today but its history survives, so last
    /// month's statistics do not quietly change. Hard deletion would also
    /// fight CloudKit once sync is on.
    func archive(_ goal: Goal) {
        var archived = goal
        archived.archivedAt = .now
        save(archived)
    }

    /// Puts a starter set of goals in an empty store.
    ///
    /// Temporary: onboarding will replace this with goals the user actually
    /// chooses.
    func seedIfEmpty() {
        guard goals.isEmpty else { return }

        let starters = [
            GoalTemplateCatalog.read,
            GoalTemplateCatalog.pushUps,
            GoalTemplateCatalog.water,
            GoalTemplateCatalog.quitSmoking,
            GoalTemplateCatalog.gym
        ]

        do {
            for template in starters {
                // The template carries a key, not a word: these titles are the
                // first thing a user ever sees and must arrive in their own
                // language.
                let title = String(localized: String.LocalizationValue(template.titleKey))
                try store.save(template.makeGoal(title: title))
            }
            goals = try store.loadGoals()
        } catch {
            failure = String(localized: "Couldn't set up your first goals. \(error.localizedDescription)")
        }
    }
}
