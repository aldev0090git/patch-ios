import Foundation
import PatchCore

/// Temporary in-memory goals so the app has something to show before
/// SwiftData persistence lands. Replaced by a repository in the next step.
enum SampleData {
    static let goals: [Goal] = [
        GoalTemplateCatalog.read.makeGoal(title: "Read"),
        GoalTemplateCatalog.pushUps.makeGoal(title: "Push-ups"),
        GoalTemplateCatalog.water.makeGoal(title: "Water"),
        GoalTemplateCatalog.quitSmoking.makeGoal(title: "Don't smoke"),
        Goal(title: "Take vitamins", symbolName: "pills", measure: .times(1)),
        GoalTemplateCatalog.gym.makeGoal(title: "Gym")
    ]
}
