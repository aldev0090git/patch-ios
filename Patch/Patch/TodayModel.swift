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

    private(set) var goals: [Goal] = []
    private(set) var entries: [Entry] = []

    /// Set when the store refuses a read or a write. Surfaced rather than
    /// swallowed: silently losing a logged entry is worse than an alert.
    var failure: String?

    init(store: GoalStore, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
        self.calculator = ProgressCalculator(calendar: calendar)
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

    func hasLoggedToday(_ goal: Goal) -> Bool {
        entries.contains { $0.goalID == goal.id && calendar.isDateInToday($0.loggedAt) }
    }

    // MARK: - Writing

    func load() {
        do {
            goals = try store.loadGoals()
            entries = try store.loadEntries()
        } catch {
            failure = "Couldn't load your goals. \(error.localizedDescription)"
        }
    }

    func log(_ amount: Decimal, for goal: Goal) {
        let entry = Entry(goalID: goal.id, amount: amount)
        do {
            try store.log(entry)
            entries.append(entry)
        } catch {
            failure = "Couldn't save that. \(error.localizedDescription)"
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
            failure = "Couldn't reset that. \(error.localizedDescription)"
        }
    }

    /// Puts a starter set of goals in an empty store.
    ///
    /// Temporary. Onboarding will replace this with goals the user actually
    /// chooses, and the titles will come from the String Catalog rather than
    /// being written in English here.
    func seedIfEmpty() {
        guard goals.isEmpty else { return }

        let starters: [(GoalTemplate, String)] = [
            (GoalTemplateCatalog.read, "Read"),
            (GoalTemplateCatalog.pushUps, "Push-ups"),
            (GoalTemplateCatalog.water, "Water"),
            (GoalTemplateCatalog.quitSmoking, "Don't smoke"),
            (GoalTemplateCatalog.gym, "Gym")
        ]

        do {
            for (template, title) in starters {
                try store.save(template.makeGoal(title: title))
            }
            goals = try store.loadGoals()
        } catch {
            failure = "Couldn't set up your first goals. \(error.localizedDescription)"
        }
    }
}
