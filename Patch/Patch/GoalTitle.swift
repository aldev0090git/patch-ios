import Foundation
import PatchCore

nonisolated extension Goal {
    /// The name to show, in the reader's language.
    ///
    /// Goals the app named — seeded ones, and anything picked during
    /// onboarding — keep a `titleKey` and are resolved here, at display time,
    /// so switching the phone's language renames them. Goals the user named
    /// have no key and are shown exactly as typed.
    ///
    /// Resolving at display time rather than at creation is the whole point:
    /// the first version saved the English word once and a Russian reader was
    /// left with "Don't smoke" sitting among Russian text forever.
    var localizedTitle: String {
        guard let titleKey, !titleKey.isEmpty else { return title }
        let resolved = String(localized: String.LocalizationValue(titleKey))
        // A key missing from the catalog resolves to itself. Showing
        // "template.read" to a user would be worse than the stale fallback.
        return resolved == titleKey ? title : resolved
    }
}

nonisolated extension Goal {
    /// What to store after someone edits a goal's name.
    ///
    /// Split out from the editor view so the rule can be tested: it is easy to
    /// break by writing the typed string straight into `title`, which would
    /// silently freeze every seeded goal into the current language — the exact
    /// bug `localizedTitle` exists to fix.
    static func titleToSave(typed: String, editing existing: Goal?) -> (title: String, key: String?) {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let existing, let key = existing.titleKey else { return (trimmed, nil) }
        // Unchanged means the user never touched the template's name, so it
        // keeps following the phone's language.
        return trimmed == existing.localizedTitle ? (existing.title, key) : (trimmed, nil)
    }
}
