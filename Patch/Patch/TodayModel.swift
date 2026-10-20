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
    private let healthImporter: HealthImporter

    /// Guards against two imports overlapping. Launch fires one and the first
    /// `scenePhase` change can fire another; both would read the same entries
    /// before either had written, and log the same delta twice.
    private var isImporting = false

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
        self.healthImporter = HealthImporter(reader: HealthKitReader.shared, calendar: calendar)
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

    /// Every goal scheduled for today is done.
    ///
    /// Empty is **not** complete: a day with nothing to do has not been
    /// finished, it just has no work in it, and telling someone they have
    /// cleared a day they never started is a lie they will notice.
    var isDayComplete: Bool {
        let today = todaysProgress
        return !today.isEmpty && today.allSatisfy(\.isAchieved)
    }

    func hasLoggedToday(_ goal: Goal) -> Bool {
        entries.contains { $0.goalID == goal.id && calendar.isDateInToday($0.loggedAt) }
    }

    // MARK: - Writing

    func load() {
        do {
            goals = GoalOrder.sorted(try store.loadGoals())
            entries = try store.loadEntries()
            publishToWidget()
        } catch {
            failure = String(localized: "Couldn't load your goals. \(error.localizedDescription)")
        }
    }

    func log(_ amount: Decimal, for goal: Goal) {
        let entry = Entry(goalID: goal.id, amount: amount)
        do {
            try store.log(entry)
            entries.append(entry)
            publishToWidget()
        } catch {
            failure = String(localized: "Couldn't save that. \(error.localizedDescription)")
        }
    }

    /// Brings every Health-linked goal up to date with Apple Health.
    ///
    /// Silent in both directions: it writes nothing when there is nothing to
    /// write, and it says nothing when Health is unreadable. A permission the
    /// user declined, or a phone with no Health at all, is not an error worth
    /// an alert on the Today screen — the goal simply stays where the user
    /// left it, and can still be logged by hand.
    func importFromHealth() async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }

        let pending = await healthImporter.pendingEntries(goals: goals, entries: entries)
        guard !pending.isEmpty else { return }

        do {
            for entry in pending {
                try store.log(entry)
            }
            entries.append(contentsOf: pending)
            publishToWidget()
        } catch {
            failure = String(localized: "Couldn't save your Health data. \(error.localizedDescription)")
        }
    }

    /// Applies a drag on the Today list.
    ///
    /// `offsets` and `destination` are positions in *today's* list, which is
    /// not the whole list — a weekday goal is not on screen at the weekend.
    /// `GoalOrder` deals the visible goals back into the visible slots and
    /// leaves the rest alone; see its tests for why that matters.
    func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let visible = GoalOrder.moved(todaysGoals, fromOffsets: offsets, toOffset: destination)
        let changed = GoalOrder.reindexed(all: goals, visibleOrder: visible.map(\.id))
        guard !changed.isEmpty else { return }

        do {
            for goal in changed {
                try store.save(goal)
            }
            goals = GoalOrder.sorted(try store.loadGoals())
            publishToWidget()
            Haptics.play(.selection)
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
            publishToWidget()
        } catch {
            failure = String(localized: "Couldn't reset that. \(error.localizedDescription)")
        }
    }

    /// Creates the goal, or updates the stored one with the same id.
    func save(_ goal: Goal) {
        do {
            try store.save(goal)
            goals = GoalOrder.sorted(try store.loadGoals())
            publishToWidget()
        } catch {
            failure = String(localized: "Couldn't save that. \(error.localizedDescription)")
        }
    }

    /// Archives rather than deletes.
    ///
    /// The goal stops appearing in Today but its history survives, so last
    /// month's statistics do not quietly change. Hard deletion would also
    /// fight CloudKit once sync is on.
    /// After every write, so the home screen is never behind the app. Only
    /// on success: a failed write must not advertise a day that did not
    /// happen.
    private func publishToWidget() {
        WidgetPublisher.publish(goals: goals, entries: entries, calendar: calendar)
    }

    func archive(_ goal: Goal) {
        var archived = goal
        archived.archivedAt = .now
        save(archived)
    }
}
