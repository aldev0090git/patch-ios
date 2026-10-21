import PatchCore
import SwiftUI

struct StatisticsView: View {
    @Environment(\.themeAccent) private var themeAccent

    /// Scaled, not fixed. `Font.system(size:)` ignores Dynamic Type
    /// completely — the audit reports it as "Dynamic Type font sizes are
    /// unsupported" — so the one number this screen exists to show stayed
    /// 44pt however large the reader had set their text.
    @ScaledMetric(relativeTo: .largeTitle) private var percentSize: CGFloat = 44
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
            // A background that does not come and go. By default iOS fades
            // the bar's backing in as content scrolls under it and away
            // again at the top, so the top of the screen changes colour
            // while you scroll. `.hard` keeps it there, the same, always.
            .scrollEdgeEffectStyle(.hard, for: .top)
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            // A bar, not an inset — see the note on Today's.
            // 6, not 0. Rows carry a 6-point inset top and bottom, so two
            // cards sit 12 apart while the first card sat 6 from the bar —
            // close enough to look like a mistake rather than a rhythm.
            .safeAreaBar(edge: .top, spacing: 6) {
                PeriodBar(model: model)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            // After the inset, not before: a background applies to what
            // is above it in the chain, and the pinned header is added
            // after. Painted earlier it stopped at the header's edge and
            // left a seam across the wash.
            .background(PageBackground())
            // On every appearance, not once. A tab keeps its view alive, so
            // a goal logged on another one stayed invisible here until the
            // app was relaunched — and backdating makes that obvious.
            .onAppear { model.load() }
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
                // Same rule as the rows below: with nothing settled there is
                // no rate, and a big blue 0% reads as a verdict.
                Group {
                    if model.hasNothingToReport {
                        Text(verbatim: "—").foregroundStyle(.secondary)
                    } else {
                        Text(model.completionRate, format: .percent.precision(.fractionLength(0)))
                            .foregroundStyle(themeAccent)
                            .contentTransition(.numericText())
                    }
                }
                .font(.system(size: percentSize, weight: .bold, design: .rounded))

                Spacer()

                if model.hasNothingToReport {
                    Text("Still going today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(totals.completed) done")
                            .font(.headline)
                        Text("\(totals.missed) missed")
                            .font(.subheadline)
                            .foregroundStyle(totals.missed > 0 ? Color.goalMissed : .secondary)
                    }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        // The menu writes the selection straight through, so the feedback
        // hangs off the value rather than off a button that never runs.
        .onChange(of: model.selection.kind) { Haptics.play(.selection) }
    }

    /// One window back or forward, with a tick to say it moved. The title is
    /// the only thing that changes on screen and it is easy to miss.
    private func step(_ delta: Int) {
        withAnimation(Motion.animation(.snappy, reduceMotion: reduceMotion)) {
            model.step(by: delta)
        }
        Haptics.play(.selection)
    }

    private var stepper: some View {
        HStack(spacing: 10) {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(Text("Previous period"))

            Text(verbatim: model.periodTitle)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(minWidth: 110)
                .multilineTextAlignment(.center)

            Button { step(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
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
    @Environment(\.themeAccent) private var themeAccent
    let row: GoalStatistics

    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 34

    private var statistics: PeriodStatistics { row.statistics }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: row.goal.symbolName)
                    .font(.system(size: iconSize * 0.5))
                    .foregroundStyle(themeAccent)
                    .frame(width: iconSize, height: iconSize)
                    .background(Color(uiColor: .tertiarySystemFill), in: .circle)
                    // Decorative: the goal's name is right beside it, and the
                    // symbol has no readable name of its own.
                    .accessibilityHidden(true)

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

            if let overall = row.overall {
                OverallProgress(progress: overall, measure: row.goal.measure)
            }

            if statistics.currentStreak > 0 || statistics.total > 0 {
                HStack(spacing: 14) {
                    if statistics.currentStreak > 0 {
                        Label {
                            Text("\(statistics.currentStreak) day streak")
                        } icon: {
                            Image(systemName: "flame.fill").foregroundStyle(Color.goalMissed)
                        }
                    }
                    if statistics.total > 0, row.goal.loggingStyle != .single {
                        Label {
                            Text(verbatim: MeasureFormatter.short(
                                statistics.total,
                                measure: row.goal.measure
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
                .foregroundStyle(statistics.missedDays == 0 ? Color.goalDone : .primary)
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

/// How a long-run target is going: "12 000 ₴ of 100 000 ₴", a bar, and what
/// it would take to still make the date.
private struct OverallProgress: View {
    @Environment(\.themeAccent) private var themeAccent
    let progress: CumulativeProgress
    let measure: Measure

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: amounts)
                    .font(.caption.weight(.medium))
                Spacer(minLength: 8)
                if let note {
                    Text(verbatim: note)
                        .font(.caption)
                        .foregroundStyle(progress.isOverdue ? Color.goalMissed : .secondary)
                }
            }

            GeometryReader { proxy in
                Capsule()
                    .fill(progress.isReached ? Color.goalDone : themeAccent)
                    .frame(width: proxy.size.width * progress.fraction)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 6)
            .background(Color(uiColor: .tertiarySystemFill), in: .capsule)
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
    }

    private var amounts: String {
        let done = MeasureFormatter.short(progress.total, measure: measure)
        let target = MeasureFormatter.short(progress.target, measure: measure)
        return String(localized: "\(done) of \(target)")
    }

    /// One line, and only when it tells the reader something they could act
    /// on. A reached target says so; an overdue one says so; otherwise the
    /// useful number is the pace needed, not the raw days left.
    private var note: String? {
        if progress.isReached { return String(localized: "Reached") }
        if progress.isOverdue { return String(localized: "Past its date") }
        guard let days = progress.daysRemaining else { return nil }
        guard let pace = progress.requiredPerRemainingDay else {
            return String(localized: "\(days) days left")
        }
        let amount = MeasureFormatter.short(pace, measure: measure)
        return String(localized: "\(amount) a day to make it")
    }
}

/// Done against missed, as one bar.
///
/// Drawn from the two counts rather than from a fraction so that a window with
/// nothing settled yet renders as an empty track instead of a misleading zero.
private struct SplitBar: View {
    @Environment(\.themeAccent) private var themeAccent
    let completed: Int
    let missed: Int

    private var total: Int { completed + missed }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: total > 0 && completed > 0 && missed > 0 ? 2 : 0) {
                if completed > 0 {
                    Capsule().fill(themeAccent)
                        .frame(width: width(completed, in: proxy.size.width))
                }
                if missed > 0 {
                    Capsule().fill(Color.goalMissed.opacity(0.75))
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
