import PatchCore
import SwiftUI

/// The day at a glance, above the goal list.
///
/// Shows two different things deliberately. The percentage is the *average of
/// every goal's own progress*, so a half-finished day reads as moving rather
/// than as zero — counting only finished goals makes the morning feel like no
/// progress at all. The "n of m done" count is the honest, bragging number.
///
/// One bar segment per goal, each filling with that goal's fraction, so you can
/// see which goal is lagging without reading the list.
struct TodayProgressHeader: View {
    let progress: [DayProgress]

    /// Scaled, not fixed. `Font.system(size:)` ignores Dynamic Type
    /// completely — the audit reports it as "Dynamic Type font sizes are
    /// unsupported" — so the one number this screen exists to show stayed
    /// 46pt however large the reader had set their text.
    @ScaledMetric(relativeTo: .largeTitle) private var percentSize: CGFloat = 46

    private var completed: Int { progress.count(where: \.isAchieved) }

    private var overallFraction: Double {
        guard !progress.isEmpty else { return 0 }
        return progress.reduce(0) { $0 + $1.fraction } / Double(progress.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(overallFraction, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: percentSize, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: overallFraction))
                    .foregroundStyle(allDone ? AnyShapeStyle(Color.goalDone) : AnyShapeStyle(.tint))

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(completed) of \(progress.count)")
                        .font(.headline)
                        .contentTransition(.numericText(value: Double(completed)))
                    Text(allDone ? "All done" : "goals done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SegmentedBar(progress: progress)
                .frame(height: 10)
        }
        .animation(.snappy, value: overallFraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's progress")
        .accessibilityValue("\(completed) of \(progress.count) goals done")
    }

    private var allDone: Bool { !progress.isEmpty && completed == progress.count }
}

/// One capsule per goal, filled by that goal's own progress.
private struct SegmentedBar: View {
    let progress: [DayProgress]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(progress.enumerated()), id: \.offset) { _, day in
                Capsule()
                    .fill(.quaternary)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(fill(for: day))
                                // A failed day fills completely in orange: an
                                // empty segment would be indistinguishable from
                                // one simply not started yet.
                                .frame(width: proxy.size.width * (day.isFailed ? 1 : day.fraction))
                        }
                    }
                    .clipShape(.capsule)
            }
        }
        .animation(.snappy, value: progress.map(\.fraction))
    }

    private func fill(for day: DayProgress) -> AnyShapeStyle {
        if day.isAchieved { return AnyShapeStyle(Color.goalDone) }
        if day.isFailed { return AnyShapeStyle(Color.goalMissed) }
        return AnyShapeStyle(.tint)
    }
}
