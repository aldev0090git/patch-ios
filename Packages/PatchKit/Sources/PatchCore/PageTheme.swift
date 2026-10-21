import Foundation

/// One end of a page gradient, as plain components.
///
/// Not a `Color`. This is `PatchCore`, which is Foundation-only so its tests
/// run in milliseconds with no simulator — and the widget is a separate
/// process that cannot see the app's types anyway. Both sides turn these
/// numbers into their own colours, which is the point: the numbers live once,
/// so the home screen cannot drift away from the app.
public struct ThemeStop: Codable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// The wash behind the cards.
///
/// Gradients rather than photographs, and deliberately. Patch is white cards
/// on a page, and the cards cover most of the screen — a photograph would
/// show as slivers between them, which is not enough to be beautiful and
/// quite enough to make the cards look like they are floating on somebody
/// else's screenshot. Statistics is the real test: a chart needs its
/// gridlines, and they are the first thing a busy background eats.
///
/// Stored by `rawValue` and also encoded into ``WidgetSnapshot``, so the
/// cases are a persisted format twice over. Renaming one drops every install
/// that chose it back to `plain`.
public enum PageTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    /// The flat page. Not an absence of theme — the default, and the one
    /// tuned against the card colour rather than chosen for looks.
    /// The near-white page iOS gives a grouped list, and the default.
    ///
    /// It is what Patch looked like before any of this, and what people kept
    /// going back to looking for.
    case paper
    /// A few percent deeper than `paper`, which separates the white cards
    /// more firmly. The same page, read as a taste rather than a mistake.
    case plain
    case gold
    case roseGold
    case platinum

    public var id: String { rawValue }

    /// Top to bottom, or `nil` for the flat page, which each target already
    /// has its own colour for.
    ///
    /// Light-mode stops stay above about 0.72 at their darkest. White cards
    /// have nowhere to go, so the page has to stay well clear of them —
    /// the same constraint that set the plain page at 0.915.
    ///
    /// Dark mode has the opposite problem and needed a second pass. Dark
    /// cards are `#1C1C1E`, about 0.11, and the first attempt put the page
    /// at roughly the same brightness — so the wash had nothing to show
    /// against and every theme read as plain black with a hint of
    /// something. These stops run from clearly above the card at the top to
    /// well below it at the bottom, which is what makes the gradient
    /// visible at all.
    public func stops(dark: Bool) -> [ThemeStop]? {
        switch (self, dark) {
        case (.plain, _):
            nil

        // Two identical stops: a flat fill, written as a gradient so it
        // travels the same road as the rest — including into the widget,
        // which cannot see a `UIColor`. These are `systemGroupedBackground`
        // spelled out, #F2F2F7 and black.
        case (.paper, false):
            [ThemeStop(0.949, 0.949, 0.969), ThemeStop(0.949, 0.949, 0.969)]
        case (.paper, true):
            [ThemeStop(0, 0, 0), ThemeStop(0, 0, 0)]

        case (.gold, false):
            [ThemeStop(0.980, 0.955, 0.900), ThemeStop(0.920, 0.860, 0.720)]
        case (.gold, true):
            [ThemeStop(0.165, 0.125, 0.055), ThemeStop(0.045, 0.034, 0.014)]

        case (.roseGold, false):
            [ThemeStop(0.985, 0.945, 0.930), ThemeStop(0.940, 0.830, 0.800)]
        case (.roseGold, true):
            [ThemeStop(0.170, 0.085, 0.095), ThemeStop(0.050, 0.026, 0.030)]

        case (.platinum, false):
            [ThemeStop(0.955, 0.965, 0.975), ThemeStop(0.850, 0.880, 0.910)]
        case (.platinum, true):
            [ThemeStop(0.080, 0.105, 0.145), ThemeStop(0.026, 0.034, 0.048)]
        }
    }

    /// What an install gets before anyone chooses.
    public static let standard: PageTheme = .paper

    /// Falls back rather than failing. A missing value is a fresh install; an
    /// unknown one means a snapshot or a preference written by a build that
    /// offers a theme this one does not. Neither is worth a crash, and both
    /// want the default.
    public static func stored(_ rawValue: String?) -> PageTheme {
        guard let rawValue else { return .standard }
        return PageTheme(rawValue: rawValue) ?? .standard
    }
}
