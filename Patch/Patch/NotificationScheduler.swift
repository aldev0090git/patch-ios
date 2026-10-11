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
    /// plan is small, rebuilding it is cheap, and a diff that goes wrong
    /// leaves someone being reminded about a goal they deleted.
    func sync(goals: [Goal]) async {
        let planned = ReminderPlanner.plan(for: goals)
        let existing = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: existing)

        guard !planned.isEmpty, await isAuthorized else { return }

        let titles = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0.localizedTitle) })
        for reminder in planned {
            let content = UNMutableNotificationContent()
            content.title = titles[reminder.goalID] ?? String(localized: "Patch")
            content.body = String(localized: "Still to do today.")
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
