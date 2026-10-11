import UIKit

/// Every vibration the app plays, in one place.
///
/// Deliberately imperative, rather than SwiftUI's `.sensoryFeedback(trigger:)`.
/// All of these acknowledge something the user *just did*, so they belong in
/// the action that did it. A trigger-based modifier fires on any change to
/// the value it watches — including the one the store makes when the screen
/// first loads — so a day that was already logged would buzz the phone on
/// launch, and resetting a goal would be indistinguishable from logging one
/// because both move the same number.
@MainActor
enum Haptics {
    /// What happened, not which generator to use. Call sites should not have
    /// to know that "the day is finished" is a heavy tap and a success note;
    /// if that choice turns out to be wrong it should change here only.
    enum Event {
        /// An amount was added and there is still more to do.
        case logged
        /// That amount finished a goal.
        case completed
        /// That amount finished the last goal of the day.
        case allDone
        /// Today's entries for a goal were thrown away.
        case reset
        /// A goal was archived.
        case archived
        /// A choice changed: a template, a day, a colour, a period.
        case selection
        /// Something failed and an alert is about to say so.
        case failure
    }

    static func play(_ event: Event) {
        guard isEnabled else { return }

        switch event {
        case .logged:
            // Soft and light. This one fires most often by a wide margin, and
            // anything firmer turns a four-tap morning into a nuisance.
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

        case .completed:
            UINotificationFeedbackGenerator().notificationOccurred(.success)

        case .allDone:
            // Two beats, because finishing the day is the one moment the app
            // has worth celebrating and a single note is the same thing the
            // user already felt on the goal before it. The gap is long enough
            // to read as deliberate rather than as a stutter.
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(130))
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }

        case .reset:
            // Rigid: a short, hard click. Undoing work should feel like a
            // switch being thrown back, not like more work being done.
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        case .archived:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)

        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()

        case .failure:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    /// Read straight from `UserDefaults` rather than taken as a parameter, so
    /// no call site has to carry the setting around to reach a vibration.
    /// `@AppStorage` writes to this same store, so the toggle in Settings and
    /// this are the same value.
    ///
    /// Absent means on: a fresh install should feel like the rest of iOS.
    ///
    /// Internal rather than private so a test can pin that default. The switch
    /// above is a lookup table with nothing to get wrong; this is the one line
    /// here that could silently stop honouring the user's choice.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.haptics) as? Bool ?? true
    }
}
