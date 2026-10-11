import Foundation
import PatchCore

/// One notification that should exist.
///
/// A plain value so the decision of *what* to schedule can be tested without
/// touching `UNUserNotificationCenter`, which needs a real app and a user
/// tapping Allow.
nonisolated struct PlannedReminder: Hashable, Identifiable {
    let id: String
    let goalID: Goal.ID
    /// `nil` means every day; otherwise the `Calendar` weekday number.
    let weekday: Int?
    let hour: Int
    let minute: Int

    /// What the trigger needs. A weekday here is what keeps a Monday and
    /// Wednesday goal from nagging on a Sunday.
    var components: DateComponents {
        var parts = DateComponents(hour: hour, minute: minute)
        parts.weekday = weekday
        return parts
    }
}

/// Works out which notifications a set of goals should have.
///
/// `nonisolated` so the tests can call it off the main actor; see
/// `MeasureFormatter` for why the app target makes that necessary.
nonisolated enum ReminderPlanner {
    /// One request per day the goal actually runs on.
    ///
    /// iOS repeats a calendar trigger on whatever components it is given, so a
    /// daily goal needs one request and a three-day-a-week goal needs three.
    /// Archived goals get none — being reminded about something you have put
    /// away is the fastest way to have notifications switched off entirely.
    static func plan(for goals: [Goal]) -> [PlannedReminder] {
        goals
            .filter { !$0.isArchived }
            .flatMap(plan(for:))
            .sorted { $0.id < $1.id }
    }

    static func plan(for goal: Goal) -> [PlannedReminder] {
        guard !goal.isArchived, let reminder = goal.reminder else { return [] }

        switch goal.schedule {
        case .daily:
            return [
                PlannedReminder(
                    id: identifier(goal: goal.id, weekday: nil),
                    goalID: goal.id,
                    weekday: nil,
                    hour: reminder.hour,
                    minute: reminder.minute
                )
            ]
        case .daysOfWeek(let days):
            return days.sorted().map { day in
                PlannedReminder(
                    id: identifier(goal: goal.id, weekday: day.rawValue),
                    goalID: goal.id,
                    weekday: day.rawValue,
                    hour: reminder.hour,
                    minute: reminder.minute
                )
            }
        }
    }

    /// Stable and derived from the goal, so rescheduling replaces a goal's own
    /// notifications instead of piling duplicates on top of them.
    static func identifier(goal: Goal.ID, weekday: Int?) -> String {
        weekday.map { "goal.\(goal.uuidString).\($0)" } ?? "goal.\(goal.uuidString).daily"
    }
}
