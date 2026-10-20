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
    /// What to show when ``titleKey`` is nil, and the fallback if a key ever
    /// goes missing from the catalog.
    public var title: String
    /// Set only while a goal still carries the name its template gave it.
    ///
    /// Seeded and onboarding goals are named by the app, not the user, so they
    /// should follow the phone's language rather than freezing into whichever
    /// language happened to run first. Renaming clears this: a title someone
    /// typed is theirs, and translating it out from under them would be wrong.
    /// The domain stores the key and has no opinion about resolving it.
    public var titleKey: String?
    /// SF Symbol name, so the app stays visually native for free.
    public var symbolName: String
    public var measure: Measure
    public var direction: Direction
    public var schedule: Schedule
    /// Optional long-run target: "save 20 000 UAH", "read 100 hours".
    /// Separate from the daily target — a goal can have either, both or neither.
    public var cumulativeTarget: Decimal?
    /// When the long-run target is meant to be reached by. Optional on its own:
    /// "save 20 000" is a goal with or without a date, and inventing a deadline
    /// nobody set would turn a saving habit into a countdown.
    public var cumulativeDeadline: Date?
    public var createdAt: Date
    /// Past daily targets, oldest first. Empty while the target has never
    /// changed — see ``dailyTarget(on:calendar:)``.
    public var targetHistory: [TargetChange]
    /// Where this goal sits in the list the user arranged.
    ///
    /// Zero for every goal until someone reorders, which is why sorting is
    /// always `(sortIndex, createdAt)` — with the whole list at zero the
    /// creation date decides, which is exactly the order the app had before
    /// this existed.
    public var sortIndex: Int
    /// Set when the user asks for this goal to be filled in from Apple
    /// Health. Nil — the default, and the only value most goals ever have —
    /// means Patch never looks at Health for it.
    public var healthSource: HealthSource?
    /// Archived goals stop appearing in Today but keep their history.
    /// Soft deletion also avoids destructive CloudKit sync surprises.
    public var archivedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        titleKey: String? = nil,
        symbolName: String = "target",
        measure: Measure,
        direction: Direction = .atLeast,
        schedule: Schedule = .daily,
        cumulativeTarget: Decimal? = nil,
        cumulativeDeadline: Date? = nil,
        createdAt: Date = .now,
        targetHistory: [TargetChange] = [],
        sortIndex: Int = 0,
        healthSource: HealthSource? = nil,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.titleKey = titleKey
        self.symbolName = symbolName
        self.measure = measure
        self.direction = direction
        self.schedule = schedule
        self.cumulativeTarget = cumulativeTarget
        self.cumulativeDeadline = cumulativeDeadline
        self.createdAt = createdAt
        self.targetHistory = targetHistory
        self.sortIndex = sortIndex
        self.healthSource = healthSource
        self.archivedAt = archivedAt
    }

    public var isArchived: Bool { archivedAt != nil }
}
