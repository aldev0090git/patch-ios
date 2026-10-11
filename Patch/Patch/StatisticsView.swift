import PatchCore
import SwiftUI

struct StatisticsView: View {
    @State var model: StatisticsModel

    var body: some View {
        NavigationStack {
            List {
                if model.rows.isEmpty {
                    emptyState
                } else {
                    Section { summaryCard.listRow() }
                    Section {
                        ForEach(model.rows) { row in
                            GoalStatisticsCard(row: row).listRow()
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                PeriodBar(model: model)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .background(.bar)
            }
            .task { model.load() }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { model.failure != nil },
                    set: { if !$0 { model.failure = nil } }
                )
            ) {
                Button("OK", role: .cancel) { model.failure = nil }
            } message: {
                Text(model.failure ?? "")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Nothing to report yet",
            systemImage: "chart.bar",
            description: Text("Once you have tracked a goal for a day or two, its numbers show up here.")
        )
        .listRow()
    }

    /// The window as a whole: one rate, and the two counts behind it.
    private var summaryCard: some View {
        let totals = model.totals

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.completionRate, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                    .contentTransition(.numericText())

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(totals.completed) done")
                        .font(.headline)
                    Text("\(totals.missed) missed")
                        .font(.subheadline)
                        .foregroundStyle(totals.missed > 0 ? .orange : .secondary)
                }
            }

            // Done and missed as one bar rather than two numbers: the split is
            // the point, and a bar shows it without being read.
            SplitBar(completed: totals.completed, missed: totals.missed)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .animation(.snappy, value: totals.completed)
        .animation(.snappy, value: totals.missed)
    }
}

/// Picks the kind of window, and walks backwards and forwards through it.
private struct PeriodBar: View {
    @Bindable var model: StatisticsModel

    var body: some View {
        HStack(spacing: 12) {
            // A menu rather than a segmented picker: five options do not fit
            // across a phone, and the custom range needs somewhere to live.
            Menu {
                Picker("Period", selection: $model.selection.kind) {
                    ForEach(PeriodKind.allCases) { kind in
                        Text(verbatim: kind.title).tag(kind)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: 4) {
                    Text(verbatim: model.selection.kind.title).font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(uiColor: .secondarySystemFill))
                .clipShape(.capsule)
            }
            .accessibilityLabel(Text("Period"))

            Spacer(minLength: 0)

            if model.selection.kind == .custom {
                customRange
            } else {
                stepper
            }
        }
        .foregroundStyle(.primary)
    }

    private var stepper: some View {
        HStack(spacing: 10) {
            Button { withAnimation(.snappy) { model.step(by: -1) } } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(Text("Previous period"))

            Text(verbatim: model.periodTitle)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(minWidth: 110)
                .multilineTextAlignment(.center)

            Button { withAnimation(.snappy) { model.step(by: 1) } } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel(Text("Next period"))
            // Nothing has happened in the future. A live arrow that walks into
            // empty windows looks like the data is missing.
            .disabled(!model.canStepForward)
        }
        .buttonStyle(.plain)
        .font(.subheadline.weight(.semibold))
    }

    private var customRange: some View {
        HStack(spacing: 6) {
            DatePicker(
                "Start",
                selection: $model.selection.customStart,
                in: ...Date.now,
                displayedComponents: .date
            )
            .labelsHidden()

            Text(verbatim: "–").foregroundStyle(.secondary)

            DatePicker(
                "End",
                selection: $model.selection.customEnd,
                in: ...Date.now,
                displayedComponents: .date
            )
            .labelsHidden()
        }
    }
}

/// One goal's record over the window.
private struct GoalStatisticsCard: View {
    let row: GoalStatistics

    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 34

    private var statistics: PeriodStatistics { row.statistics }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: row.goal.symbolName)
                    .font(.system(size: iconSize * 0.5))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: iconSize, height: iconSize)
                    .background(Color(uiColor: .tertiarySystemFill), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: row.goal.localizedTitle)
                        .font(.headline)
                    Text(verbatim: detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                rate
            }

            SplitBar(completed: statistics.completedDays, missed: statistics.missedDays)

            if statistics.currentStreak > 0 || statistics.total > 0 {
                HStack(spacing: 14) {
                    if statistics.currentStreak > 0 {
                        Label {
                            Text("\(statistics.currentStreak) day streak")
                        } icon: {
                            Image(systemName: "flame.fill").foregroundStyle(.orange)
                        }
                    }
                    if statistics.total > 0, row.goal.loggingStyle != .single {
                        Label {
                            Text(verbatim: MeasureFormatter.short(
                                statistics.total,
                                kind: row.goal.measure.kind
                            ))
                        } icon: {
                            Image(systemName: "sum")
                        }
                    }
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
    }

    /// A rate only means something once a day has settled. Until then the
    /// honest answer is a dash — 0% reads as failure, and green 0% reads as a
    /// bug.
    @ViewBuilder
    private var rate: some View {
        if statistics.scheduledDays == 0 {
            Text(verbatim: "—")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            Text(statistics.completionRate, format: .percent.precision(.fractionLength(0)))
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(statistics.missedDays == 0 ? .green : .primary)
        }
    }

    private var detail: String {
        guard statistics.scheduledDays > 0 else {
            return String(localized: "Still going today")
        }
        let done = String(localized: "\(statistics.completedDays) done")
        let missed = String(localized: "\(statistics.missedDays) missed")
        return "\(done) · \(missed)"
    }
}

/// Done against missed, as one bar.
///
/// Drawn from the two counts rather than from a fraction so that a window with
/// nothing settled yet renders as an empty track instead of a misleading zero.
private struct SplitBar: View {
    let completed: Int
    let missed: Int

    private var total: Int { completed + missed }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: total > 0 && completed > 0 && missed > 0 ? 2 : 0) {
                if completed > 0 {
                    Capsule().fill(Color.accentColor)
                        .frame(width: width(completed, in: proxy.size.width))
                }
                if missed > 0 {
                    Capsule().fill(Color.orange.opacity(0.75))
                        .frame(width: width(missed, in: proxy.size.width))
                }
                if total == 0 {
                    Capsule().fill(Color(uiColor: .tertiarySystemFill))
                }
            }
        }
        .frame(height: 8)
        .background(Color(uiColor: .tertiarySystemFill), in: .capsule)
        .clipShape(.capsule)
        .accessibilityElement()
        .accessibilityLabel(Text("\(completed) done, \(missed) missed"))
    }

    private func width(_ count: Int, in available: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        return available * CGFloat(count) / CGFloat(total)
    }
}

private extension View {
    /// The card inset used on both scrolling screens, kept in one place.
    func listRow() -> some View {
        listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
