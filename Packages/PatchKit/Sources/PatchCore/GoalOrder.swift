import Foundation

/// The order goals appear in, and how dragging one changes it.
///
/// Creation date decided this until now, which is an implementation detail
/// showing through: "Read, Water, Push-ups" is the order a seeder happened to
/// insert them, not an order anybody chose.
public enum GoalOrder {
    /// Display order: what the user arranged, falling back to when the goal
    /// was made.
    ///
    /// The fallback is what makes this safe to introduce. Every existing goal
    /// has `sortIndex` 0, so until someone drags something the comparison is
    /// decided entirely by `createdAt` — byte for byte the order the app
    /// showed yesterday.
    public static func sorted(_ goals: [Goal]) -> [Goal] {
        goals.sorted {
            $0.sortIndex == $1.sortIndex
                ? $0.createdAt < $1.createdAt
                : $0.sortIndex < $1.sortIndex
        }
    }

    /// Applies a drag, in the terms `List.onMove` reports it.
    ///
    /// Written out rather than using SwiftUI's `move(fromOffsets:toOffset:)`,
    /// so the model layer does not have to import SwiftUI to reorder an
    /// array — and so the index arithmetic, which is the part that is easy to
    /// get subtly wrong, is covered by tests.
    ///
    /// `destination` is the position *before the removal*, which is why it
    /// has to be adjusted by however many of the moved rows sat above it.
    public static func moved(_ goals: [Goal], fromOffsets offsets: IndexSet, toOffset destination: Int) -> [Goal] {
        let taken = offsets.sorted().compactMap { goals.indices.contains($0) ? goals[$0] : nil }
        guard !taken.isEmpty else { return goals }

        var remaining = goals
        for index in offsets.sorted(by: >) where remaining.indices.contains(index) {
            remaining.remove(at: index)
        }

        let above = offsets.count { $0 < destination }
        let insertion = min(max(0, destination - above), remaining.count)
        remaining.insert(contentsOf: taken, at: insertion)
        return remaining
    }

    /// Reindexes everything so the goals on screen end up in `visibleOrder`.
    ///
    /// **The screen is not the whole list.** Today shows only what is
    /// scheduled for today, so a weekday-only goal is invisible on Sunday —
    /// and dragging two visible goals past each other must not move it. The
    /// hidden ones keep the slots they already occupy; the visible ones are
    /// dealt back into the visible slots in their new order.
    ///
    /// - Parameters:
    ///   - all: every goal to be ordered, in current display order.
    ///   - visibleOrder: the ids that were on screen, in the order the user
    ///     has just put them. Ids not in `all` are ignored.
    /// - Returns: only the goals whose index actually changed, so a drag
    ///   writes two rows rather than twenty.
    public static func reindexed(all: [Goal], visibleOrder: [Goal.ID]) -> [Goal] {
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let moving = visibleOrder.compactMap { byID[$0] }
        let movingIDs = Set(moving.map(\.id))

        var next = moving.makeIterator()
        let rearranged = all.map { goal in
            // A visible slot takes the next goal from the new order; a hidden
            // goal stays exactly where it was.
            movingIDs.contains(goal.id) ? (next.next() ?? goal) : goal
        }

        return rearranged.enumerated().compactMap { index, goal in
            guard goal.sortIndex != index else { return nil }
            var moved = goal
            moved.sortIndex = index
            return moved
        }
    }
}
