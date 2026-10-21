import PatchCore
import SwiftUI

/// The keys the look-and-feel settings are stored under.
///
/// Spelled once, because `@AppStorage` in a view and `UserDefaults` in
/// ``Haptics`` have to agree and the compiler cannot check a string literal.
nonisolated enum SettingsKey {
    static let appearance = "appearance"
    static let accent = "accentTheme"
    static let pageTheme = "pageTheme"
    static let haptics = "hapticsEnabled"
    static let remindersEnabled = "remindersEnabled"
    static let reminderTimes = "reminderTimes"
}

/// Light, dark, or whatever the phone is doing.
///
/// Stored by `rawValue`, so the cases are a persisted format: rename one and
/// every install that chose it silently falls back to `system`.
nonisolated enum Appearance: String, CaseIterable, Identifiable, Hashable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// `nil` means "don't force anything", which is what `system` is.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

}

/// The colour the app leans on: the ring while a goal is running, the tick in
/// a list, the selected day in the calendar.
///
/// **No green, and nothing near it.** Green already means *a day that is
/// done* and orange means *a day that was missed* — see ``Color/goalDone``.
/// An accent that lands on either would make "in progress" and "finished"
/// the same colour on the same card, which is the one distinction the Today
/// screen exists to draw. The six here are all comfortably clear of both.
nonisolated enum AccentTheme: String, CaseIterable, Identifiable, Hashable {
    case blue
    case indigo
    case violet
    case teal
    case rose
    case graphite

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: .blue
        case .indigo: .indigo
        case .violet: .purple
        case .teal: .teal
        case .rose: Color(red: 0.90, green: 0.33, blue: 0.47)
        // Not `.gray`, which is the same mid tone in both appearances and
        // sinks into a grouped background. `.primary` inverts with the
        // scheme — near-black on white, near-white on black — which makes
        // this the one genuinely monochrome option rather than a grey one.
        case .graphite: .primary
        }
    }

    var title: String {
        switch self {
        case .blue: String(localized: "Blue")
        case .indigo: String(localized: "Indigo")
        case .violet: String(localized: "Violet")
        case .teal: String(localized: "Teal")
        case .rose: String(localized: "Rose")
        case .graphite: String(localized: "Graphite")
        }
    }

    /// Falls back rather than failing: an unknown stored value means a build
    /// that offered a colour this one does not, and the right answer to that
    /// is the default, not a crash.
    static func stored(_ rawValue: String) -> AccentTheme {
        AccentTheme(rawValue: rawValue) ?? .blue
    }
}

extension Color {
    /// The page behind the cards.
    ///
    /// Not `systemGroupedBackground` in light mode, which is **#F2F2F7**
    /// against cards of pure white — about three percent apart. Dark mode
    /// gets away with the same pairing because a card that is *lighter* than
    /// near-black separates instantly; in light mode the card has nowhere
    /// left to go, so it stops reading as an object and the screen flattens
    /// into one white field.
    ///
    /// A few percent deeper is all it takes. Dark mode keeps the system
    /// colour, where nothing was wrong.
    static let page = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .systemGroupedBackground
            : UIColor(white: 0.915, alpha: 1)
    })

    /// What a card casts onto the page, in light mode only.
    ///
    /// A black shadow under a dark-mode card is either invisible or dirt, so
    /// it is switched off there rather than tuned down.
    static func cardShadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .clear : .black.opacity(0.09)
    }

    /// A scheduled day that was met. Deliberately **not** part of the theme.
    ///
    /// Done and missed are states, not decoration. Letting them follow the
    /// accent would mean the same card reads green-for-finished under one
    /// theme and green-for-in-progress under another, and someone who learnt
    /// the screen once would have to learn it again.
    static let goalDone = Color.green

    /// A scheduled day that was not met. Not red: a missed day is worth
    /// noticing, not an error, and the app does not tell people off.
    static let goalMissed = Color.orange
}

extension EnvironmentValues {
    /// The accent as a *value*, for the places that need a `Color` rather
    /// than a style — a fill, an opacity, a stroke.
    ///
    /// `Color.accentColor` cannot do this job: it reads the asset catalog and
    /// ignores `.tint(_:)` entirely, so every one of those call sites stayed
    /// blue while the rest of the app changed colour. `.tint` still handles
    /// controls; this covers the rest.
    @Entry var themeAccent: Color = .blue

    /// The wash behind the cards. Read by ``PageBackground`` and by nothing
    /// else — screens ask for the background, not for the theme.
    @Entry var pageTheme: PageTheme = .plain
}

extension Color {
    /// `PatchCore` carries the stops as plain numbers, because it is
    /// Foundation-only and the widget is a different process. This is the
    /// whole of the conversion; the widget has the same eight lines, and the
    /// numbers they both read live in ``PageTheme``.
    init(_ stop: ThemeStop) {
        self.init(red: stop.red, green: stop.green, blue: stop.blue)
    }
}

extension PageTheme {
    func gradient(_ scheme: ColorScheme) -> LinearGradient? {
        guard let stops = stops(dark: scheme == .dark) else { return nil }
        return LinearGradient(
            colors: stops.map(Color.init),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var title: String {
        switch self {
        case .paper: String(localized: "Paper")
        case .plain: String(localized: "Grey")
        case .gold: String(localized: "Gold")
        case .roseGold: String(localized: "Rose Gold")
        case .platinum: String(localized: "Platinum")
        }
    }
}

/// What every screen paints behind itself.
///
/// A view rather than a `Color`, because a gradient is not a colour and the
/// screens should not have to know which they are getting. It ignores the
/// safe area so the wash runs under the navigation bar and the tab bar —
/// stopping at either would draw a line across the gradient exactly where
/// the eye expects it to continue.
struct PageBackground: View {
    @Environment(\.pageTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let gradient = theme.gradient(colorScheme) {
                gradient
            } else {
                Color.page
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
