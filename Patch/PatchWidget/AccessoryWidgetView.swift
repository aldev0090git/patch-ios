import PatchCore
import SwiftUI
import WidgetKit

/// Today on the Lock Screen, and in the Smart Stack on a watch-style layout.
///
/// These render in a **monochrome** mode — iOS flattens them to the Lock
/// Screen's tint and ignores colour entirely. So nothing here may rely on
/// green to mean "done": the tick does that job, as it does for anyone with
/// the app in greyscale. `.widgetAccentable()` marks the parts that should
/// take the accent where the system offers one.
///
/// They read the same snapshot as the home-screen widget. No migration, no
/// database, no extra work for the app.
struct AccessoryWidgetView: View {
    let snapshot: WidgetSnapshot?

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryInline: inline
        default: rectangular
        }
    }

    // MARK: - Circular

    /// A ring beside the clock, with the app's mark inside it.
    ///
    /// Built by hand rather than with `Gauge(.accessoryCircularCapacity)`,
    /// which draws the number alone: on a Lock Screen that already shows a
    /// battery ring, a bare "50%" in a circle is indistinguishable from it.
    /// Every one of Apple's own circular widgets carries a glyph for the same
    /// reason — the ring says how much, the symbol says of what.
    ///
    /// The percentage drops its sign. At this size the "%" costs a point of
    /// font size for no information: nothing else in the ring is a number.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Circle()
                .stroke(.tertiary, lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.02, fraction))
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            VStack(spacing: -2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9, weight: .semibold))
                Text(percentValue, format: .number)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.7)
            }
        }
    }

    // MARK: - Rectangular

    /// Three lines under the clock: how far, how many, and what is next.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let snapshot, !snapshot.items.isEmpty {
                HStack(spacing: 4) {
                    Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                        .font(.headline)
                        .widgetAccentable()
                    Text("\(snapshot.completed)/\(snapshot.scheduled)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .widgetAccentable()
                if let next = snapshot.nextUnfinished {
                    Label {
                        Text(verbatim: next.title).lineLimit(1)
                    } icon: {
                        Image(systemName: next.symbolName)
                    }
                    .font(.caption2)
                } else {
                    Text("All done").font(.caption2)
                }
            } else {
                Text("Patch").font(.headline).widgetAccentable()
                Text(snapshot == nil ? "Open Patch to get started" : "Nothing due today")
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Inline

    /// One line, beside the date. The system allows an image and a single
    /// string and will truncate it without mercy, so it says the least that
    /// is still worth saying.
    @ViewBuilder
    private var inline: some View {
        if let snapshot, !snapshot.items.isEmpty {
            Label {
                Text("\(snapshot.completed) of \(snapshot.scheduled) goals done")
            } icon: {
                Image(systemName: snapshot.isComplete ? "checkmark.circle.fill" : "checkmark.circle")
            }
        } else {
            Label("Patch", systemImage: "checkmark.circle")
        }
    }

    private var fraction: Double { snapshot?.fraction ?? 0 }

    /// Whole percent as a number, so the reader's locale formats the digits.
    /// A `Text(verbatim:)` of a hand-built string would not.
    private var percentValue: Int { Int((fraction * 100).rounded()) }
}

#Preview(as: .accessoryCircular) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: .placeholder)
}

#Preview(as: .accessoryRectangular) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: .placeholder)
    TodayEntry(date: .now, snapshot: nil)
}
