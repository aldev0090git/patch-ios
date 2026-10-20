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
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            AccessoryWidgetView(snapshot: snapshot)
        default:
            homeScreen
        }
    }

    @ViewBuilder
    private var homeScreen: some View {
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

            Spacer(minLength: 0)

            if family == .systemSmall {
                NextUpView(snapshot: snapshot)
            } else {
                GoalListView(snapshot: snapshot)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// The small widget's lower half, which used to be empty.
///
/// A small widget has room for one idea, and "what is left" beats repeating
/// the overview the bar above already gives. Underneath it, where there is
/// room, a strip of the other outstanding goals — enough to see how much is
/// left without reading anything.
private struct NextUpView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if let next = snapshot.nextUnfinished {
            // Degrades rather than clips: at large Dynamic Type sizes the
            // strip is dropped and the goal keeps its full name.
            ViewThatFits(in: .vertical) {
                VStack(alignment: .leading, spacing: 6) {
                    row(next)
                    strip(excluding: next)
                }
                row(next)
            }
        } else {
            Label("All done", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.goalDone)
                .lineLimit(1)
        }
    }

    private func row(_ next: WidgetSnapshot.Item) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Next")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Label {
                Text(verbatim: next.title).lineLimit(1)
            } icon: {
                Image(systemName: next.symbolName)
            }
            .font(.caption.weight(.medium))
        }
    }

    /// Icons only — names would not fit, and the point here is "three left",
    /// not "which three".
    @ViewBuilder
    private func strip(excluding next: WidgetSnapshot.Item) -> some View {
        let others = snapshot.remaining.filter { $0.id != next.id }.prefix(5)
        if !others.isEmpty {
            HStack(spacing: 5) {
                ForEach(others) { item in
                    Image(systemName: item.symbolName)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

/// The medium widget's list of goals.
///
/// The count is not fixed. It was `prefix(4)` with a comment claiming four was
/// what fitted; on a real phone it left visible empty space, and the fifth
/// goal simply vanished. `ViewThatFits` asks the layout instead of guessing,
/// which also means it shrinks correctly at large Dynamic Type sizes rather
/// than overflowing.
///
/// Anything that still does not fit is **counted, not hidden**. A widget
/// showing four of eight goals and saying nothing is lying by omission.
private struct GoalListView: View {
    let snapshot: WidgetSnapshot

    /// Written out rather than looped. `ViewThatFits` picks between its
    /// *children*, and whether a `ForEach` counts as one child or as many is
    /// not something to leave to inference when the failure mode is a widget
    /// that silently overflows its box.
    var body: some View {
        ViewThatFits(in: .vertical) {
            list(limit: 7)
            list(limit: 6)
            list(limit: 5)
            list(limit: 4)
            list(limit: 3)
            list(limit: 2)
            list(limit: 1)
        }
    }

    private func list(limit: Int) -> some View {
        let shown = snapshot.items.prefix(limit)
        let hidden = snapshot.items.count - shown.count
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(shown) { item in
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
            if hidden > 0 {
                Text("+\(hidden) more")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 20)
            }
        }
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

#Preview(as: .systemMedium) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: .placeholder)
}
