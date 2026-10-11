import Foundation
import Observation
import PatchCore

/// State for the first-run flow.
///
/// Owns the selection and nothing else: the goals are only written when the
/// user finishes, so backing out of onboarding leaves no trace.
@MainActor
@Observable
final class OnboardingModel {
    private let store: GoalStore

    /// Offered in the catalog's own order, which is roughly easiest first.
    let templates = GoalTemplateCatalog.all

    private(set) var selected: Set<GoalTemplate.ID>
    var failure: String?

    /// Starts with a few already ticked.
    ///
    /// An empty list asks someone who has just opened the app to invent their
    /// own habits before they know what the app does. These three are the
    /// broadest and the easiest to succeed at on day one — they are a starting
    /// point to edit, not a recommendation.
    static let suggested: Set<GoalTemplate.ID> = ["read", "water", "steps"]

    init(store: GoalStore) {
        self.store = store
        self.selected = Self.suggested
    }

    func isSelected(_ template: GoalTemplate) -> Bool {
        selected.contains(template.id)
    }

    func toggle(_ template: GoalTemplate) {
        if selected.contains(template.id) {
            selected.remove(template.id)
        } else {
            selected.insert(template.id)
        }
    }

    /// Nothing ticked is a legitimate choice — someone who wants to write their
    /// own goals should not have to pick a decoy first.
    var canFinish: Bool { true }

    var selectionCount: Int { selected.count }

    /// Writes the chosen goals. Returns false if the store refused, so the
    /// flow can stay on screen rather than dropping the user into an empty app.
    @discardableResult
    func finish(now: Date = .now) -> Bool {
        do {
            // Created in catalog order, a second apart, so Today lists them in
            // the order they were offered rather than an arbitrary one.
            for (offset, template) in templates.enumerated() where selected.contains(template.id) {
                let createdAt = now.addingTimeInterval(Double(offset))
                try store.save(template.makeLocalizedGoal(createdAt: createdAt))
            }
            return true
        } catch {
            failure = String(localized: "Couldn't create your goals. \(error.localizedDescription)")
            return false
        }
    }
}
