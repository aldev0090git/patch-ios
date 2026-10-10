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

    @Test("A clean-day goal only ever records a slip")
    func quitSmokingIsAbstinence() {
        let goal = GoalTemplateCatalog.quitSmoking.makeGoal(title: "Don't smoke")
        #expect(goal.loggingStyle == .abstinence)
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
