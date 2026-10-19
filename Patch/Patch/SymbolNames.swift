import Foundation

/// Human names for the icons a goal can wear.
///
/// Without these, VoiceOver reads an SF Symbol's raw name — the icon picker
/// announced "figure.strengthtraining.functional" and "brain.head.profile",
/// which is unusable, and the accessibility audit flags it as a label that is
/// not human-readable.
///
/// Spelled out rather than derived from the symbol name. Splitting on dots
/// would give "figure strengthtraining functional", which is worse than
/// nothing and cannot be translated.
nonisolated enum SymbolNames {
    // A lookup table, not logic. SwiftLint counts each case as a branch and
    // calls twenty of them complex, but there is nothing here to follow and
    // no other shape this can take: `String(localized:)` needs its key as a
    // literal at the call site, so a dictionary would not be extracted into
    // the catalog at all.
    // swiftlint:disable:next cyclomatic_complexity
    static func localizedName(for symbol: String) -> String {
        switch symbol {
        case "book": String(localized: "Book")
        case "pencil": String(localized: "Pencil")
        case "graduationcap": String(localized: "Graduation cap")
        case "brain.head.profile": String(localized: "Mind")
        case "figure.walk": String(localized: "Walking")
        case "figure.run": String(localized: "Running")
        case "dumbbell": String(localized: "Dumbbell")
        case "figure.strengthtraining.functional": String(localized: "Workout")
        case "drop": String(localized: "Water drop")
        case "cup.and.saucer": String(localized: "Cup")
        case "fork.knife": String(localized: "Food")
        case "pills": String(localized: "Pills")
        case "bed.double": String(localized: "Bed")
        case "moon.stars": String(localized: "Night")
        case "sun.max": String(localized: "Sun")
        case "leaf": String(localized: "Leaf")
        case "heart": String(localized: "Heart")
        case "banknote": String(localized: "Money")
        case "nosign": String(localized: "No entry")
        case "music.note": String(localized: "Music")
        // A goal created before this list existed, or by a later version.
        // Better a generic word than the raw symbol name.
        default: String(localized: "Icon")
        }
    }
}
