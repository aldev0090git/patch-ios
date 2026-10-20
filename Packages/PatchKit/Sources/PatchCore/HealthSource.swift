import Foundation

/// A quantity Patch can read out of Apple Health on the user's behalf.
///
/// **Why this is an explicit choice and not an inference.** A step goal and a
/// push-up goal are both ``MeasureKind/count`` — the domain deliberately does
/// not distinguish them, and should not start now. Nothing about "10 000" says
/// whether a phone can count it. So the user says so, once, in the editor, and
/// the goal carries the answer.
///
/// That also makes the feature general rather than a special case: any count
/// goal can be pointed at steps, any distance goal at walking distance. The
/// alternative — matching on a template id or a title — breaks the moment
/// someone renames their goal, which they are invited to do.
///
/// **The units already line up.** Patch stores counts dimensionless, distance
/// in metres and duration in seconds; HealthKit's SI units for these are
/// `count()`, `meter()` and `second()`. There is no conversion in this feature
/// and there should never need to be one — see ``measureKind``.
public enum HealthSource: String, Codable, Sendable, CaseIterable, Hashable {
    /// Steps counted by the phone and any paired watch.
    case steps
    /// Distance walked and run, in metres.
    case walkingRunningDistance
    /// Apple's own exercise minutes — the green ring — in seconds.
    case exerciseMinutes
}

extension HealthSource {
    /// The one measure kind this source can fill.
    ///
    /// A source and a goal must agree on the kind or the numbers are nonsense:
    /// metres written into a goal counting repetitions would read as a target
    /// smashed five thousand times over. ``HealthImportPlanner`` refuses a
    /// mismatch rather than trusting callers to check.
    public var measureKind: MeasureKind {
        switch self {
        case .steps: .count
        case .walkingRunningDistance: .distance
        case .exerciseMinutes: .duration
        }
    }

    /// The sources that can fill a goal of this kind, in the order to offer
    /// them. Empty for volume and currency: Health knows about water, but
    /// Patch cannot tell a water goal from any other volume, and no phone
    /// counts money.
    public static func compatible(with kind: MeasureKind) -> [HealthSource] {
        allCases.filter { $0.measureKind == kind }
    }
}
