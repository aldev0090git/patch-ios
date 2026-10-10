import Foundation
import Testing
@testable import PatchCore

@Suite("Logging style")
struct LoggingStyleTests {
    @Test("A goal you accumulate through the day is incremental")
    func readingIsIncremental() {
        let goal = Goal(title: "Read", measure: .minutes(20))
        #expect(goal.loggingStyle == .incremental)
    }

    @Test("A once-a-day goal is a single yes or no")
    func gymIsSingle() {
        let goal = GoalTemplateCatalog.gym.makeGoal(title: "Gym")
        #expect(goal.loggingStyle == .single)
    }

    @Test("Staying smoke-free is confirmed once a day, like any other single goal")
    func quitSmokingIsSingle() {
        let goal = GoalTemplateCatalog.quitSmoking.makeGoal(title: "Don't smoke")
        #expect(goal.loggingStyle == .single)
        #expect(goal.direction == .atLeast)
    }

    @Test("An allowance you can spend down is still incremental")
    func allowanceIsIncremental() {
        // "At most two coffees" has room to use, unlike "at most zero".
        let goal = Goal(title: "Coffee", measure: .times(2), direction: .atMost)
        #expect(goal.loggingStyle == .incremental)
    }

    @Test("A multi-rep goal is incremental even though it is a count")
    func pushUpsAreIncremental() {
        let goal = Goal(title: "Push-ups", measure: .times(20))
        #expect(goal.loggingStyle == .incremental)
    }
}

@Suite("Goal tints")
struct GoalTintTests {
    @Test("Every template carries a colour through to its goal")
    func templatesCarryTheirTint() {
        for template in GoalTemplateCatalog.all {
            let goal = template.makeGoal(title: "Test")
            #expect(goal.tint == template.tint)
        }
    }

    @Test("Templates do not all share one colour")
    func templatesAreVisuallyDistinct() {
        let tints = Set(GoalTemplateCatalog.all.map(\.tint))
        #expect(tints.count >= 5)
    }

    @Test("A tint survives a round trip through Codable")
    func tintIsCodable() throws {
        let goal = Goal(title: "Read", symbolName: "book", tint: .indigo, measure: .minutes(20))
        let data = try JSONEncoder().encode(goal)
        let restored = try JSONDecoder().decode(Goal.self, from: data)

        #expect(restored.tint == .indigo)
    }
}

extension GoalTintTests {
    @Test("No template claims red, which is reserved for destructive actions")
    func redIsReservedForDestructiveActions() {
        #expect(GoalTemplateCatalog.all.allSatisfy { $0.tint != .red })
    }
}
