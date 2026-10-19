import Foundation
import PatchCore
import WidgetKit

/// Keeps the home screen in step with the app.
///
/// Called after every write rather than on a timer. A widget reloaded when
/// nothing changed is wasted budget, and iOS gives each app a limited number
/// of refreshes a day; a widget that updates the moment you log something is
/// both cheaper and better.
///
/// Everything here fails quietly. A snapshot that cannot be written is a
/// stale home screen, which is a disappointment — interrupting someone's
/// logging with an alert about it would be worse.
@MainActor
enum WidgetPublisher {
    private static let store = WidgetSnapshotStore()

    static func publish(goals: [Goal], entries: [Entry], calendar: Calendar = .current) {
        store.write(
            WidgetSnapshot.today(
                goals: goals,
                entries: entries,
                // Resolved here because only the app layer knows the reader's
                // language; a seeded goal carries a key, never a word.
                titles: { $0.localizedTitle },
                calendar: calendar
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
    }
}
