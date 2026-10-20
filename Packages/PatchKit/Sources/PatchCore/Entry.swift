import Foundation

/// Where a logged amount came from.
///
/// The distinction earns its place: Apple Health's figure for today keeps
/// rising, so an import has to be able to work out how much of a day it has
/// *already* contributed and add only the difference. Without a source it
/// would have to subtract the whole day's total, quietly swallowing anything
/// the user logged by hand.
public enum EntrySource: String, Codable, Sendable, Hashable, CaseIterable {
    /// Logged by the user, by tap or by typing.
    case manual
    /// Read out of Apple Health by ``HealthImportPlanner``.
    case health
}

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
    /// Defaults to ``EntrySource/manual``, which is what every entry written
    /// before Health import existed was.
    public var source: EntrySource

    public init(
        id: UUID = UUID(),
        goalID: Goal.ID,
        amount: Decimal,
        loggedAt: Date = .now,
        note: String? = nil,
        source: EntrySource = .manual
    ) {
        self.id = id
        self.goalID = goalID
        self.amount = amount
        self.loggedAt = loggedAt
        self.note = note
        self.source = source
    }

    /// Hand-written only to make ``source`` tolerant of its own absence.
    ///
    /// The synthesised decoder throws on a missing key even when the property
    /// has a default, which would make every schema-1 archive — the exports
    /// people already have on disk — unreadable by a build that can import
    /// them. An entry with no recorded source is a manual one.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        goalID = try container.decode(UUID.self, forKey: .goalID)
        amount = try container.decode(Decimal.self, forKey: .amount)
        loggedAt = try container.decode(Date.self, forKey: .loggedAt)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        source = try container.decodeIfPresent(EntrySource.self, forKey: .source) ?? .manual
    }
}
