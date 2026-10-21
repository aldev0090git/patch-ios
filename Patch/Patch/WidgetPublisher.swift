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
                theme: storedTheme,
                calendar: calendar
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Re-dresses the snapshot already on disk.
    ///
    /// Changing the theme changes nothing about the day, so there is no
    /// reason to reload the store and recompute every goal's progress to
    /// repaint a background. If no snapshot exists yet there is no widget
    /// showing anything, and the next real write will carry the theme.
    static func republish(wearing theme: PageTheme) {
        guard let snapshot = store.read() else { return }
        store.write(snapshot.wearing(theme))
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Read from `UserDefaults` directly: `@AppStorage` is a view's way of
    /// reading the same store, and this is not a view.
    private static var storedTheme: PageTheme {
        PageTheme.stored(UserDefaults.standard.string(forKey: SettingsKey.pageTheme))
    }
}
