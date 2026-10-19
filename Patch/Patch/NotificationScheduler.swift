import Foundation
import PatchCore
import UserNotifications

/// Puts the planned reminders into iOS.
///
/// Split from ``ReminderPlanner`` on purpose: deciding *what* to schedule is
/// pure and tested, and this type only does the part that needs a real device
/// and a granted permission.
@MainActor
final class NotificationScheduler {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// Asks only when the answer is not already known.
    ///
    /// iOS shows the system prompt once per install; asking again when it has
    /// been denied does nothing, so the caller must handle a `false` by
    /// pointing at Settings rather than by asking again.
    func requestAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }

    var isAuthorized: Bool {
        get async {
            let settings = await center.notificationSettings()
            return settings.authorizationStatus != .denied
                && settings.authorizationStatus != .notDetermined
        }
    }

    /// Makes iOS match the plan exactly.
    ///
    /// Clears this app's pending requests first rather than diffing them: the
    /// plan is at most four requests, rebuilding it is cheap, and a diff that
    /// goes wrong leaves someone being reminded at a time they deleted.
    ///
    /// Called on launch and whenever the setting changes, so a reminder
    /// removed in Settings is gone from iOS before the sheet closes.
    func sync(times: [Reminder], isEnabled: Bool) async {
        let planned = ReminderPlanner.plan(times: times, isEnabled: isEnabled)
        let existing = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: existing)

        guard !planned.isEmpty, await isAuthorized else { return }

        for reminder in planned {
            let content = UNMutableNotificationContent()
            // Deliberately says nothing about which goals are outstanding,
            // and asks rather than tells. Two reasons, one technical and one
            // not.
            //
            // A repeating trigger's text is fixed when it is scheduled, so any
            // count written now would be yesterday's by the time it arrives,
            // and "3 left" when the answer is none is worse than no number.
            //
            // And a reminder that scolds gets the app muted. "Don't forget"
            // assumes the day went badly, which on most days is both wrong and
            // unpleasant; this works whether the day is finished or not.
            content.title = String(localized: "How's today going?")
            content.body = String(localized: "Tick off what you've done today.")
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: reminder.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: reminder.components,
                    repeats: true
                )
            )
            try? await center.add(request)
        }
    }
}
