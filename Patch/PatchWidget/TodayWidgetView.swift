import PatchCore
import SwiftUI
import WidgetKit

/// The home-screen face of today.
///
/// Three states, because a widget that cannot tell them apart is worse than
/// no widget: nothing written yet, a day with nothing scheduled, and a day in
/// progress. The middle one is not a zero — see the note on empty states in
/// `CLAUDE.md`.
struct TodayWidgetView: View {
    let snapshot: WidgetSnapshot?

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot, !snapshot.items.isEmpty {
            day(snapshot)
        } else {
            empty
        }
    }

    private func day(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(snapshot.fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(snapshot.isComplete ? Color.goalDone : .primary)
                Spacer(minLength: 0)
                Text("\(snapshot.completed)/\(snapshot.scheduled)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // One bar per goal, each filled by that goal's own progress — the
            // same idea as the Today header, so the two read alike.
            HStack(spacing: 3) {
                ForEach(snapshot.items) { item in
                    Capsule()
                        .fill(item.isAchieved ? Color.goalDone : Color.accentColor)
                        .opacity(item.isAchieved ? 1 : max(0.2, item.fraction))
                        .frame(height: 5)
                }
            }

            if family != .systemSmall {
                Spacer(minLength: 0)
                goalList(snapshot)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Only on the medium size. Four rows is what fits without shrinking the
    /// text below the size the reader asked for.
    private func goalList(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(snapshot.items.prefix(4)) { item in
                HStack(spacing: 6) {
                    Image(systemName: item.isAchieved ? "checkmark.circle.fill" : item.symbolName)
                        .font(.caption2)
                        .foregroundStyle(item.isAchieved ? Color.goalDone : .secondary)
                        .frame(width: 14)
                    Text(verbatim: item.title)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(item.isAchieved ? .secondary : .primary)
                }
            }
        }
    }

    /// Nothing written yet, or nothing due. Says which rather than drawing a
    /// confident 0%, which would claim a verdict the day has not reached.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "checkmark.seal")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(snapshot == nil ? "Open Patch to get started" : "Nothing due today")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Color {
    /// The widget cannot see the app's theme — it is a separate process with
    /// no access to its `UserDefaults` beyond the shared group, and the accent
    /// is not worth putting in the snapshot. It uses the system accent and the
    /// one colour that carries meaning: green is a day you finished, here as
    /// everywhere else.
    static let goalDone = Color.green
}

#Preview(as: .systemSmall) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: .placeholder)
    TodayEntry(date: .now, snapshot: nil)
}
