import PatchCore
import SwiftUI

/// Choosing what, if anything, Apple Health fills this goal in with.
///
/// **A picker, not a toggle.** It was a toggle, on the reasoning that each
/// measure kind has exactly one source today — which made the row read "Fill
/// in from Apple Health" without ever saying *from what*. Someone made a
/// Squats goal, turned it on, and Patch poured their step count into it: two
/// thousand squats, done for the day. The goal was not wrong to offer it —
/// "walk 10 000" may well be called something other than Steps — but the app
/// has to say what it is about to read, at the moment of choosing, not in a
/// footnote below the fold.
struct HealthLinkSection: View {
    let kind: MeasureKind
    @Binding var source: HealthSource?

    private var options: [HealthSource] { HealthSource.compatible(with: kind) }

    var body: some View {
        Section {
            Picker(selection: $source) {
                Text("Off").tag(HealthSource?.none)
                ForEach(options, id: \.self) { option in
                    Self.name(of: option).tag(HealthSource?.some(option))
                }
            } label: {
                Label("Fill in from Health", systemImage: "heart.fill")
            }
            .accessibilityIdentifier("editor.health")
        } header: {
            Text("Apple Health")
        } footer: {
            // Only once something is chosen. Explaining a feature that is
            // switched off is noise, and this screen is already long.
            if let source {
                VStack(alignment: .leading, spacing: 6) {
                    Self.explanation(for: source)
                    Text("""
                        You can still log by hand, and both will count. \
                        If nothing appears, check Settings \u{203A} Privacy & Security \u{203A} Health.
                        """)
                }
            }
        }
    }

    /// Returns `Text`, not a `String`, so every branch is a literal the
    /// catalog can see — see the Localisation notes in `CLAUDE.md`.
    private static func name(of source: HealthSource) -> Text {
        switch source {
        case .steps: Text("Steps")
        case .walkingRunningDistance: Text("Walking distance")
        case .exerciseMinutes: Text("Exercise minutes")
        }
    }

    private static func explanation(for source: HealthSource) -> Text {
        switch source {
        case .steps:
            Text("Patch reads your step count each day and keeps this goal up to date.")
        case .walkingRunningDistance:
            Text("Patch reads how far you walked and ran each day and keeps this goal up to date.")
        case .exerciseMinutes:
            Text("Patch reads your exercise minutes each day and keeps this goal up to date.")
        }
    }
}
