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
                symbol: "arrow.right",
                title: Text("Swipe right to edit"),
                detail: Text(
                    "Change the target, days or reminder at any time. Past days keep the target they had."
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

/// The same three tips as a screen of their own, for the Settings route.
struct HowItWorksSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                HowItWorksView()
                    .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
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
