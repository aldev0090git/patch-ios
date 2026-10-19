import SwiftUI

/// Chooses animations that respect **Reduce Motion**.
///
/// People turn that setting on because movement on screen makes them ill —
/// vestibular disorders, vertigo, migraine. For them a panel that slides or a
/// tick that springs in from nothing is not decoration, it is a symptom.
///
/// The rule iOS itself follows is **replace movement with a cross-fade**, not
/// remove feedback. Something still has to say the state changed; it just must
/// not travel, scale or overshoot. That is why the reduced animation here is a
/// short flat fade rather than `nil`: an instant jump leaves the user
/// wondering whether their tap registered.
///
/// `nonisolated` so the choice can be tested without a view; see
/// `MeasureFormatter` for why the app target makes that necessary.
nonisolated enum Motion {
    /// How long a reduced animation lasts. Long enough to be noticed, short
    /// enough that nothing reads as moving.
    static let reducedDuration = 0.15

    /// The animation to use, given what the view would like.
    static func animation(_ preferred: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: reducedDuration) : preferred
    }

    /// How something should arrive and leave.
    ///
    /// Scaling and sliding are precisely what the setting exists to stop, so
    /// they collapse to a cross-fade.
    static func transition(_ preferred: AnyTransition, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : preferred
    }
}
