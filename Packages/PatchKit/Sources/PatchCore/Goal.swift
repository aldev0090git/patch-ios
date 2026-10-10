import Foundation

/// Which way a goal is trying to go.
public enum Direction: String, Codable, Sendable, CaseIterable, Hashable {
    /// The day succeeds once the total reaches the target. "Read 20 minutes."
    case atLeast
    /// The day succeeds while the total stays at or below the target.
    /// "Don't smoke" (target 0), or "at most two coffees".
    case atMost
}

/// A single thing the user is trying to do, repeatedly.
///
/// Deliberately unit-agnostic: reading, push-ups, water, steps, money saved and
/// not smoking are all the same shape — accumulate an amount, compare it to a
/// daily target in a direction. Adding a new kind of goal later means adding a
/// ``MeasureKind``, not changing this type or migrating the store.
public struct Goal: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var title: String
    /// SF Symbol name, so the app stays visually native for free.
    public var symbolName: String
    public var measure: Measure
    public var direction: Direction
    public var schedule: Schedule
    /// Optional long-run target: "save 20 000 UAH", "read 100 hours".
    /// Separate from the daily target — a goal can have either, both or neither.
    public var cumulativeTarget: Decimal?
    public var createdAt: Date
    /// Archived goals stop appearing in Today but keep their history.
    /// Soft deletion also avoids destructive CloudKit sync surprises.
    public var archivedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        symbolName: String = "target",
        measure: Measure,
        direction: Direction = .atLeast,
        schedule: Schedule = .daily,
        cumulativeTarget: Decimal? = nil,
        createdAt: Date = .now,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.measure = measure
        self.direction = direction
        self.schedule = schedule
        self.cumulativeTarget = cumulativeTarget
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }

    public var isArchived: Bool { archivedAt != nil }
}
