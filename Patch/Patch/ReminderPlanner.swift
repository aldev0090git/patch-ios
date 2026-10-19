import Foundation
import PatchCore

/// One notification that should exist.
///
/// A plain value so the decision of *what* to schedule can be tested without
/// touching `UNUserNotificationCenter`, which needs a real app and a user
/// tapping Allow.
nonisolated struct PlannedReminder: Hashable, Identifiable {
    let id: String
    let hour: Int
    let minute: Int

    /// An hour and a minute with no day, which is what makes a calendar
    /// trigger repeat daily. One request per check-in, for ever — see
    /// ``DailyCheckIns`` for why that ceiling matters.
    var components: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }
}

/// Works out which notifications the app should have.
///
/// `nonisolated` so the tests can call it off the main actor; see
/// `MeasureFormatter` for why the app target makes that necessary.
nonisolated enum ReminderPlanner {
    /// One request per check-in time, or none at all when reminders are off.
    ///
    /// Nothing here looks at goals. A reminder is a nudge to open Patch, not a
    /// per-habit alarm, so an archived goal, a goal that only runs on Mondays
    /// and a goal created this morning all make no difference to the plan.
    static func plan(times: [Reminder], isEnabled: Bool = true) -> [PlannedReminder] {
        guard isEnabled else { return [] }
        return DailyCheckIns.normalised(times).map {
            PlannedReminder(id: identifier(for: $0), hour: $0.hour, minute: $0.minute)
        }
    }

    /// Stable and derived from the time, so rescheduling replaces a check-in's
    /// notification instead of piling duplicates on top of it.
    static func identifier(for reminder: Reminder) -> String {
        String(format: "checkin.%02d%02d", reminder.hour, reminder.minute)
    }
}
