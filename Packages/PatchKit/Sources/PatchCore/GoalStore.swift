import Foundation

/// Where goals and entries live.
///
/// The domain declares what it needs and the app supplies it, so `PatchCore`
/// never learns that SwiftData exists. Tests use an in-memory implementation
/// and run in milliseconds without a container, a simulator or a disk.
///
/// Deliberately dumb: it loads, saves and deletes, and holds no opinion about
/// what a day means or which entries belong to it. Anything that needs a
/// calendar belongs in ``ProgressCalculator`` or the view layer, where it can
/// be tested without a store at all.
///
/// `@MainActor` because the realistic implementation is SwiftData's
/// `ModelContext`, which is main-actor bound. Pretending otherwise would push
/// that problem into every call site.
@MainActor
public protocol GoalStore: AnyObject {
    func loadGoals() throws -> [Goal]
    func loadEntries() throws -> [Entry]

    /// Inserts the goal, or updates the stored one with the same id.
    func save(_ goal: Goal) throws

    func log(_ entry: Entry) throws
    func deleteEntries(ids: [Entry.ID]) throws
}

/// A store that forgets everything when it goes away.
///
/// Used by tests and SwiftUI previews. Keeping it in the domain rather than the
/// test target means previews get it too, without the app depending on a test
/// bundle.
@MainActor
public final class InMemoryGoalStore: GoalStore {
    private var goals: [Goal]
    private var entries: [Entry]

    public init(goals: [Goal] = [], entries: [Entry] = []) {
        self.goals = goals
        self.entries = entries
    }

    public func loadGoals() throws -> [Goal] { goals }

    public func loadEntries() throws -> [Entry] { entries }

    public func save(_ goal: Goal) throws {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
        } else {
            goals.append(goal)
        }
    }

    public func log(_ entry: Entry) throws {
        entries.append(entry)
    }

    public func deleteEntries(ids: [Entry.ID]) throws {
        let doomed = Set(ids)
        entries.removeAll { doomed.contains($0.id) }
    }
}
