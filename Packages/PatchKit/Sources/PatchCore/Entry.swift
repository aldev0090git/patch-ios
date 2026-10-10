import Foundation

/// One logged contribution toward a goal.
///
/// Entries are append-only in spirit: to correct a mistake you add a negative
/// amount rather than mutating history. That keeps a day's total auditable and
/// avoids edit conflicts once CloudKit sync is switched on.
public struct Entry: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let goalID: Goal.ID
    /// Amount in the goal's canonical unit. May be negative to correct an error.
    public var amount: Decimal
    public var loggedAt: Date
    public var note: String?

    public init(
        id: UUID = UUID(),
        goalID: Goal.ID,
        amount: Decimal,
        loggedAt: Date = .now,
        note: String? = nil
    ) {
        self.id = id
        self.goalID = goalID
        self.amount = amount
        self.loggedAt = loggedAt
        self.note = note
    }
}
