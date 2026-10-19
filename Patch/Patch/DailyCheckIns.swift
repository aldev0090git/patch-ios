import Foundation
import PatchCore

/// The times of day Patch asks you to come back, for the whole app.
///
/// **One set of reminders, not one per goal.** Per-goal reminders sounded
/// thorough and were worse in three ways. They nag: five habits with a time
/// each is five notifications a day, and the fastest way to have notifications
/// switched off for an app is to send five. They are tedious: a time has to be
/// set, and kept, on every goal separately. And they silently broke — iOS
/// allows **64 pending local notifications per app**, and one request per day
/// a goal runs on meant ten weekday goals asked for seventy. iOS keeps the 64
/// soonest and discards the rest, with no error, so some reminders simply
/// never arrived.
///
/// A handful of whole-app check-ins cannot hit that ceiling: the cap here is
/// ``maximum``, which is four requests in total, for ever.
nonisolated enum DailyCheckIns {
    /// Midday and mid-evening: one while the day can still be rescued, one
    /// late enough to catch what was done but not logged, and early enough
    /// that it is not a reminder to feel bad in bed.
    static let standard = [Reminder(hour: 12, minute: 0), Reminder(hour: 20, minute: 0)]

    /// Four is already more than anyone needs and is a long way under the 64
    /// iOS allows, which leaves room for whatever a later version adds.
    static let maximum = 4

    /// Stored as `"12:00,20:00"` rather than as JSON, so the setting stays
    /// readable in `UserDefaults` and can be passed to a UI test as a launch
    /// argument the same way the theme is.
    static func parse(_ raw: String) -> [Reminder] {
        let times = raw
            .split(separator: ",")
            .compactMap { reminder(from: $0.trimmingCharacters(in: .whitespaces)) }
        return normalised(times)
    }

    static func text(_ times: [Reminder]) -> String {
        normalised(times)
            .map { String(format: "%02d:%02d", $0.hour, $0.minute) }
            .joined(separator: ",")
    }

    /// Sorted, de-duplicated and capped — the three things a stored list can
    /// be wrong about. Two reminders at the same minute are one reminder, and
    /// out-of-order times make a list that is read top to bottom a puzzle.
    static func normalised(_ times: [Reminder]) -> [Reminder] {
        Array(Set(times)).sorted().prefix(maximum).map { $0 }
    }

    /// A time the list does not already hold, for the Add button.
    ///
    /// An hour after the last one, so tapping Add twice gives two distinct
    /// times rather than two identical ones that collapse into one.
    static func suggestedAddition(after times: [Reminder]) -> Reminder {
        guard let last = normalised(times).last else { return standard[0] }
        return Reminder(hour: min(last.hour + 1, 23), minute: last.minute)
    }

    private static func reminder(from text: String) -> Reminder? {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        return Reminder(hour: hour, minute: minute)
    }
}
