import Foundation

/// A time of day to be reminded, in the user's own calendar.
///
/// Deliberately not a `Date`: a reminder is "half past eight", not an instant.
/// Storing an instant would drift across time zones and daylight saving, and
/// would need rewriting every day.
public struct Reminder: Hashable, Sendable, Codable {
    public let hour: Int
    public let minute: Int

    /// Clamped rather than failable. A stored value outside these ranges means
    /// a bug or a corrupt row, and refusing to build the goal at all would
    /// lose the whole goal over a reminder.
    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    /// The reminder as components, for a calendar-based notification trigger.
    public var components: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }
}
