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
