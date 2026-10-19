import Foundation

/// A time of day to be reminded, in the user's own calendar.
///
/// Deliberately not a `Date`: a reminder is "half past eight", not an instant.
/// Storing an instant would drift across time zones and daylight saving, and
/// would need rewriting every day.
///
/// Reminders belong to the *app*, not to a goal — a nudge to open Patch, not
/// one per habit. See `DailyCheckIns` for why.
public struct Reminder: Hashable, Sendable, Codable, Comparable {
    public let hour: Int
    public let minute: Int

    /// Clamped rather than failable. A value outside these ranges means a bug
    /// or a corrupt setting, and refusing to build it at all would lose every
    /// reminder over one bad number.
    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    /// The reminder as components, for a calendar-based notification trigger.
    public var components: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    /// Ordered by clock time, so a list of check-ins reads down the day.
    public static func < (lhs: Reminder, rhs: Reminder) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}
