import Foundation
import PatchCore
import Testing
@testable import Patch

@Suite("Onboarding")
struct OnboardingModelTests {
    @MainActor
    private func model(_ store: GoalStore = InMemoryGoalStore()) -> OnboardingModel {
        OnboardingModel(store: store)
    }

    /// Drives the selection the way the screen does — through `toggle` — so
    /// the tests exercise the real path rather than reaching past it.
    @MainActor
    private func select(_ ids: [GoalTemplate.ID], in model: OnboardingModel) {
        for template in model.templates where model.isSelected(template) {
            model.toggle(template)
        }
        for id in ids {
            guard let template = GoalTemplateCatalog.template(id: id) else { continue }
            model.toggle(template)
        }
    }

    @MainActor
    @Test("Opens with a few already picked, so the first screen is not a blank form")
    func startsWithSuggestions() {
        let model = model()
        #expect(model.selectionCount == OnboardingModel.suggested.count)
        #expect(model.selectionCount > 0)
    }

    @MainActor
    @Test("Every suggested id matches a real template")
    func suggestionsExist() {
        for id in OnboardingModel.suggested {
            #expect(GoalTemplateCatalog.template(id: id) != nil, "no template with id \(id)")
        }
    }

    @MainActor
    @Test("Tapping a row selects it, tapping again clears it")
    func togglingIsReversible() {
        let model = model()
        let template = GoalTemplateCatalog.meditate
        #expect(!model.isSelected(template))

        model.toggle(template)
        #expect(model.isSelected(template))

        model.toggle(template)
        #expect(!model.isSelected(template))
    }

    @MainActor
    @Test("Finishing writes exactly the goals that were ticked")
    func finishWritesTheSelection() throws {
        let store = InMemoryGoalStore()
        let model = model(store)
        select(["read", "gym"], in: model)

        #expect(model.finish())

        let titles = try store.loadGoals().map(\.titleKey)
        #expect(Set(titles.compactMap { $0 }) == ["template.read", "template.gym"])
    }

    @MainActor
    @Test("Goals arrive in the order they were offered, not an arbitrary one")
    func finishPreservesCatalogOrder() throws {
        let store = InMemoryGoalStore()
        let model = model(store)
        // Deliberately not in catalog order.
        select(["meditate", "read", "water"], in: model)

        #expect(model.finish())

        let order = try store.loadGoals()
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap(\.titleKey)
        #expect(order == ["template.read", "template.water", "template.meditate"])
    }

    @MainActor
    @Test("Goals created here keep their key, so they follow the phone's language")
    func createdGoalsStayTranslatable() throws {
        let store = InMemoryGoalStore()
        let model = model(store)
        select(["water"], in: model)
        #expect(model.finish())

        let goal = try #require(try store.loadGoals().first)
        #expect(goal.titleKey == "template.water")
        #expect(!goal.title.isEmpty)
    }

    @MainActor
    @Test("Picking nothing is allowed and writes nothing")
    func pickingNothingIsAllowed() throws {
        let store = InMemoryGoalStore()
        let model = model(store)
        select([], in: model)

        #expect(model.canFinish)
        #expect(model.finish())
        #expect(try store.loadGoals().isEmpty)
    }

    @MainActor
    @Test("A store that refuses to write says so instead of dropping the goals")
    func writeFailureIsSurfaced() {
        let model = model(FailingOnboardingStore())
        select(["read"], in: model)

        #expect(model.finish() == false)
        #expect(model.failure != nil)
    }
}

@Suite("Template summaries")
struct TemplateSummaryTests {
    private let locale = Locale(identifier: "en_GB")

    private func calendar(firstWeekday: Int = 2) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func summary(_ template: GoalTemplate, firstWeekday: Int = 2) -> String {
        TemplateSummary.text(
            for: template,
            calendar: calendar(firstWeekday: firstWeekday),
            locale: locale
        )
    }

    @Test("A daily goal with an amount says both")
    func dailyAmount() {
        let text = summary(GoalTemplateCatalog.read)
        #expect(text.contains("20"))
        #expect(text.lowercased().contains("every day"))
    }

    @Test("A once-a-day confirmation drops the meaningless 1")
    func confirmationHasNoAmount() {
        // "1 every day" reads like a bug; the schedule is the whole story.
        #expect(summary(GoalTemplateCatalog.quitSmoking) == "Every day")
    }

    @Test("A goal on certain days names them")
    func namedWeekdays() {
        let text = summary(GoalTemplateCatalog.gym)
        #expect(text.contains("Mon"))
        #expect(text.contains("Wed"))
        #expect(text.contains("Fri"))
    }

    @Test("Weekdays are listed in the reader's own week order")
    func weekOrderFollowsTheLocale() {
        // Sunday-first locales must not be handed a Monday-first list.
        let template = GoalTemplate(
            id: "probe",
            titleKey: "template.gym",
            symbolName: "dumbbell",
            measure: .times(1),
            schedule: .daysOfWeek([.sunday, .monday])
        )
        let sundayFirst = summary(template, firstWeekday: 1)
        let mondayFirst = summary(template, firstWeekday: 2)

        #expect(sundayFirst.hasPrefix("Sun"))
        #expect(mondayFirst.hasPrefix("Mon"))
    }

    @Test("Every template produces a non-empty line")
    func allTemplatesDescribeThemselves() {
        for template in GoalTemplateCatalog.all {
            #expect(!summary(template).isEmpty, "\(template.id) had no summary")
        }
    }
}

@MainActor
private final class FailingOnboardingStore: GoalStore {
    struct Nope: Error, LocalizedError {
        var errorDescription: String? { "disk on fire" }
    }

    func loadGoals() throws -> [Goal] { throw Nope() }
    func loadEntries() throws -> [Entry] { throw Nope() }
    func save(_ goal: Goal) throws { throw Nope() }
    func log(_ entry: Entry) throws { throw Nope() }
    func deleteEntries(ids: [Entry.ID]) throws { throw Nope() }
}
