import PatchCore
import SwiftUI

/// The three shapes every goal in Patch takes, as cards you can actually tap.
///
/// Live cards rather than pictures of cards. A screenshot goes stale the next
/// time the design moves, cannot translate itself, ignores the reader's theme
/// and text size, and — most of the way to the point — cannot be tapped.
/// Tapping is the lesson: that amounts add up, that a limit fills the other
/// way, that one tap finishes a once-a-day goal.
///
/// The examples are the real ``GoalCard``, driven by local state, so they
/// cannot drift from the thing they are teaching.
struct GoalShapesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ShapeExample(
                heading: Text("Add up to a target"),
                detail: Text("Tap an amount and it adds up through the day until you reach it."),
                goal: GoalTemplateCatalog.read.makeLocalizedGoal()
            )
            ShapeExample(
                heading: Text("Once a day"),
                detail: Text("One tap. For the things you either did or you didn't."),
                goal: GoalTemplateCatalog.gym.makeLocalizedGoal()
            )
            ShapeExample(
                heading: Text("Stay under a limit"),
                detail: Text("Log each one. The day stays good while you are inside the limit."),
                goal: Self.allowance
            )
        }
    }

    /// No template offers an allowance, and it is the shape nobody guesses —
    /// which is exactly why it has to be shown rather than described.
    private static var allowance: Goal {
        Goal(
            title: String(localized: "Coffee"),
            symbolName: "cup.and.saucer",
            measure: .times(2),
            direction: .atMost
        )
    }
}

/// One example: what it is for, then a working card.
private struct ShapeExample: View {
    let heading: Text
    let detail: Text
    let goal: Goal

    /// The card's whole world. Nothing here is written to the store — these
    /// goals do not exist, and tapping one must not create anything.
    @State private var total: Decimal = 0

    private var progress: DayProgress {
        DayProgress(
            date: .now,
            total: total,
            target: goal.measure.dailyTarget,
            direction: goal.direction,
            isScheduled: true
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            heading
                .font(.subheadline.weight(.semibold))
            detail
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GoalCard(goal: goal, progress: progress, streak: 0) { amount in
                total += amount
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ScrollView { GoalShapesView().padding(20) }
}
