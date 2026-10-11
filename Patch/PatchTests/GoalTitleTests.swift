import Foundation
import PatchCore
import Testing
@testable import Patch

@Suite("Goal titles")
struct GoalTitleTests {
    @Test("A template goal resolves its key instead of showing the saved word")
    func templateTitleResolves() {
        let goal = GoalTemplateCatalog.read.makeGoal(title: "stale")
        #expect(goal.localizedTitle == "Read")
    }

    @Test("A goal the user named is shown exactly as typed")
    func userTitleIsVerbatim() {
        let goal = Goal(title: "Walk the dog", measure: .times(1))
        #expect(goal.localizedTitle == "Walk the dog")
    }

    @Test("A key missing from the catalog falls back rather than showing the key")
    func unknownKeyFallsBack() {
        let goal = Goal(title: "Read", titleKey: "template.nonexistent", measure: .minutes(20))
        #expect(goal.localizedTitle == "Read")
    }

    @Test("Leaving a template's name alone keeps it translatable")
    func unchangedNameKeepsKey() {
        let goal = GoalTemplateCatalog.water.makeGoal(title: "Water")
        let saved = Goal.titleToSave(typed: "Water", editing: goal)
        #expect(saved.key == "template.water")
        #expect(saved.title == "Water")
    }

    @Test("Whitespace around an untouched name still counts as untouched")
    func whitespaceDoesNotCountAsRenaming() {
        let goal = GoalTemplateCatalog.water.makeGoal(title: "Water")
        #expect(Goal.titleToSave(typed: "  Water  ", editing: goal).key == "template.water")
    }

    @Test("Renaming a template goal makes the name the user's own")
    func renamingClearsKey() {
        let goal = GoalTemplateCatalog.water.makeGoal(title: "Water")
        let saved = Goal.titleToSave(typed: "Hydrate", editing: goal)
        #expect(saved.key == nil)
        #expect(saved.title == "Hydrate")
    }

    @Test("A brand new goal never picks up a key")
    func newGoalHasNoKey() {
        #expect(Goal.titleToSave(typed: "Stretch", editing: nil).key == nil)
    }

    @Test("Renaming a goal that never had a key leaves it keyless")
    func renamingUserGoalStaysKeyless() {
        let goal = Goal(title: "Walk the dog", measure: .times(1))
        let saved = Goal.titleToSave(typed: "Walk the dogs", editing: goal)
        #expect(saved.key == nil)
        #expect(saved.title == "Walk the dogs")
    }
}

@Suite("Editing a goal's target")
struct GoalEditorTargetTests {
    /// Mirrors what the editor does on Save, so the rule is pinned even though
    /// the view itself cannot be instantiated in a unit test.
    private func edited(_ existing: Goal, to canonical: Decimal, kindChanged: Bool = false) -> Goal {
        guard !kindChanged else {
            var fresh = existing
            fresh.measure = Measure(kind: .count, dailyTarget: canonical)
            fresh.targetHistory = []
            return fresh
        }
        return existing.withTarget(canonical)
    }

    /// Created a fortnight ago, which is the case that has a past worth
    /// protecting.
    private func oldGoal() -> Goal {
        Goal(
            title: "Read",
            measure: .minutes(20),
            createdAt: Date.now.addingTimeInterval(-14 * 86_400)
        )
    }

    @Test("Raising a target records what it used to be")
    func raisingRecordsHistory() {
        let raised = edited(oldGoal(), to: 3600)

        #expect(raised.measure.dailyTarget == 3600)
        #expect(raised.targetHistory.count == 2)
        #expect(raised.targetHistory.first?.dailyTarget == 1200)
        #expect(raised.targetHistory.last?.dailyTarget == 3600)
    }

    @Test("A goal created today has no past to protect, so one entry is enough")
    func sameDayGoalCollapses() {
        // The original and the change would both be effective from today;
        // recording both would say the target changed before the goal existed.
        let raised = edited(Goal(title: "Read", measure: .minutes(20)), to: 3600)

        #expect(raised.targetHistory.count == 1)
        #expect(raised.measure.dailyTarget == 3600)
    }

    @Test("Saving without touching the target records nothing")
    func unchangedTargetAddsNoHistory() {
        #expect(edited(oldGoal(), to: 1200).targetHistory.isEmpty)
    }

    @Test("Changing the measure kind drops the history, because the unit changed")
    func changingKindClearsHistory() {
        // 1200 seconds and 1200 push-ups are not comparable numbers; keeping
        // the old entries would judge past days against a different quantity.
        let switched = edited(oldGoal().withTarget(3600), to: 50, kindChanged: true)

        #expect(switched.targetHistory.isEmpty)
        #expect(switched.measure.kind == .count)
        #expect(switched.measure.dailyTarget == 50)
    }
}
