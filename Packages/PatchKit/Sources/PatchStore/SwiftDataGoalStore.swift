import Foundation
import PatchCore
import SwiftData

/// The real store, backed by SwiftData.
///
/// Everything SwiftData-shaped stops here: the rest of the app, and all of
/// `PatchCore`, only ever sees domain values.
@MainActor
public final class SwiftDataGoalStore: GoalStore {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func loadGoals() throws -> [Goal] {
        let descriptor = FetchDescriptor<StoredGoal>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor).map(\.domain)
    }

    public func loadEntries() throws -> [Entry] {
        let descriptor = FetchDescriptor<StoredEntry>(
            sortBy: [SortDescriptor(\.loggedAt, order: .forward)]
        )
        return try context.fetch(descriptor).map(\.domain)
    }

    public func save(_ goal: Goal) throws {
        let id = goal.id
        var descriptor = FetchDescriptor<StoredGoal>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.apply(goal)
        } else {
            context.insert(StoredGoal(goal))
        }
        try context.save()
    }

    public func log(_ entry: Entry) throws {
        context.insert(StoredEntry(entry))
        try context.save()
    }

    public func deleteEntries(ids: [Entry.ID]) throws {
        guard !ids.isEmpty else { return }
        let doomed = Set(ids)
        let descriptor = FetchDescriptor<StoredEntry>(
            predicate: #Predicate { doomed.contains($0.id) }
        )
        for stored in try context.fetch(descriptor) {
            context.delete(stored)
        }
        try context.save()
    }
}
