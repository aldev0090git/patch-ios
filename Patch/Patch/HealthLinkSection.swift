import PatchCore
import SwiftUI

/// The "fill this goal in from Apple Health" row in the goal editor.
///
/// Its own file because `GoalEditor` is already at SwiftLint's limit for a
/// type body, and because this is a self-contained decision with a long
/// explanation attached — the same reason `GoalCard` was split up.
///
/// A toggle rather than a picker: every measure kind has exactly one source
/// today. If one ever gains two — mindful minutes alongside exercise minutes,
/// say — this becomes a picker over `HealthSource.compatible(with:)`, which
/// already returns a list for that reason.
struct HealthLinkSection: View {
    let option: HealthSource
    @Binding var source: HealthSource?

    var body: some View {
        Section {
            Toggle(isOn: Binding(
                get: { source == option },
                set: { source = $0 ? option : nil }
            )) {
                Label("Fill in from Apple Health", systemImage: "heart.fill")
            }
            .accessibilityIdentifier("editor.health")
        } header: {
            Text("Apple Health")
        } footer: {
            // The second line says where to go if nothing appears, because
            // the app genuinely cannot tell. iOS reports a refused read as
            // "no data", exactly like a day spent on the sofa, so an app that
            // claimed to detect a refusal would be guessing.
            VStack(alignment: .leading, spacing: 6) {
                explanation
                Text("""
                    You can still log by hand, and both will count. \
                    If nothing appears, check Settings \u{203A} Privacy & Security \u{203A} Health.
                    """)
            }
        }
    }

    /// Returns `Text`, not a `String` or a `LocalizedStringKey`, so every
    /// branch is a literal the catalog can see — see the Localisation notes
    /// in `CLAUDE.md`, where passing a literal through a `String` shipped
    /// English into an otherwise translated screen.
    private var explanation: Text {
        switch option {
        case .steps:
            Text("Patch reads your step count each day and keeps this goal up to date.")
        case .walkingRunningDistance:
            Text("Patch reads how far you walked and ran each day and keeps this goal up to date.")
        case .exerciseMinutes:
            Text("Patch reads your exercise minutes each day and keeps this goal up to date.")
        }
    }
}
