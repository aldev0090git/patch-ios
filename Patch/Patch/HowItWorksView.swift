import SwiftUI

/// The three gestures the app depends on and none of which are visible.
///
/// Lives on its own rather than inside `OnboardingView` because it is shown
/// twice: once on the last onboarding page, and again from Settings. Someone
/// who tapped through the welcome in a hurry has no other way to find out
/// that Reset exists, and "read it once on day one" is not a way to teach a
/// gesture.
struct HowItWorksView: View {
    var body: some View {
        VStack(spacing: 14) {
            TipRow(
                symbol: "hand.tap",
                title: Text("Tap an amount to log it"),
                detail: Text("Or use Manual for anything else. The ring fills as the day goes.")
            )
            TipRow(
                symbol: "arrow.left",
                title: Text("Swipe a goal left to reset or archive it"),
                detail: Text(
                    "Reset clears today's entries for that goal. Archiving hides it but keeps its history."
                )
            )
            TipRow(
                symbol: "calendar",
                title: Text("Missed a day? Fix it later"),
                detail: Text(
                    "Open the day in the Calendar and log it there. Nothing stops you going back."
                )
            )
            TipRow(
                symbol: "arrow.right",
                title: Text("Swipe right to edit"),
                detail: Text(
                    "Change the target or the days at any time. Past days keep the target they had."
                )
            )
        }
    }
}

/// One thing worth knowing.
struct TipRow: View {
    let symbol: String
    let title: Text
    let detail: Text

    @Environment(\.themeAccent) private var themeAccent
    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 34

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: iconSize * 0.45, weight: .semibold))
                .foregroundStyle(themeAccent)
                .frame(width: iconSize, height: iconSize)
                .background(Color(uiColor: .tertiarySystemFill), in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                title.font(.subheadline.weight(.semibold))
                detail
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The whole explanation as a screen of its own, for the Settings route.
///
/// Two halves, in the order someone needs them: what a goal *can be* — the
/// three shapes, as cards they can tap — and then the gestures for working
/// with one. The shapes come first because the gestures make no sense until
/// you know what you are gesturing at.
struct HowItWorksSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What a goal can be")
                            .font(.title3.bold())
                        Text("Three shapes cover everything Patch tracks. The examples below are real — tap them.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        GoalShapesView()
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Working with a goal")
                            .font(.title3.bold())
                        HowItWorksView()
                    }
                }
                .padding(20)
            }
            .background(Color.page)
            .navigationTitle("How it works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    HowItWorksSheet()
}
