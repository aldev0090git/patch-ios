import PatchCore
import SwiftUI

/// What happened on the day the user tapped — and the only place a day that
/// has already passed can be corrected.
///
/// Tapping a row logs against *that* day rather than today. The controls are
/// the ones the goal already has on the Today screen — a once-a-day goal
/// toggles, an incremental one opens the same amount picker — because a goal
/// should not behave differently depending on which screen you reached it
/// from.
struct SelectedDayCard: View {
    @Environment(\.themeAccent) private var themeAccent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var model: CalendarModel

    /// Which goal's amount picker is open. One optional rather than a bool
    /// plus a goal, which can disagree with each other.
    @State private var entering: Goal?

    private var day: Date { model.selectedDay ?? .now }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.headline)
                Spacer()
                Button("Close", systemImage: "xmark") {
                    withAnimation(Motion.animation(.snappy, reduceMotion: reduceMotion)) {
                        model.selectedDay = nil
                    }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
            }

            let rows = model.selectedDayProgress
            if rows.isEmpty {
                Text("Nothing was scheduled.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    goalRow(row)
                }
                if model.isSelectedDayWritable {
                    // Nothing about a list of rows says it can be written to,
                    // and a feature nobody finds may as well not exist.
                    Text("Tap a goal to log it for this day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .sheet(item: $entering) { goal in
            ManualEntrySheet(goal: goal) { amount in
                log(amount, for: goal)
            }
        }
    }

    /// A row is a button only when the day can actually take an entry. A
    /// future day, or a goal that was not scheduled, stays plain text — a
    /// control that does nothing is worse than no control.
    @ViewBuilder
    private func goalRow(_ row: DayGoalProgress) -> some View {
        if model.canLog(row.goal, on: day) {
            // Two sibling buttons rather than one with a button inside it:
            // nesting them makes the outer tap area swallow the inner one.
            HStack(spacing: 6) {
                Button {
                    tapped(row)
                } label: {
                    rowContent(row)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if model.hasLogged(row.goal, on: day) {
                        Button("Clear this day", systemImage: "arrow.uturn.backward", role: .destructive) {
                            clear(row.goal)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: accessibilityLabel(row)))
                .accessibilityHint(hint(for: row))
                .accessibilityAddTraits(row.progress.isAchieved ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("day.row")

                // On the row, not only behind a long press. Reset spent a
                // release hidden behind a swipe nobody found, and a way to
                // undo that only the author knows about is not a way to undo.
                if model.hasLogged(row.goal, on: day) {
                    Button("Clear this day", systemImage: "arrow.uturn.backward") {
                        clear(row.goal)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
                    .accessibilityIdentifier("day.clear")
                }
            }
        } else {
            rowContent(row)
        }
    }

    private func rowContent(_ row: DayGoalProgress) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.goal.symbolName)
                .font(.footnote)
                .foregroundStyle(themeAccent)
                .frame(width: 26, height: 26)
                .background(Color(uiColor: .tertiarySystemFill), in: .circle)
                .accessibilityHidden(true)

            Text(verbatim: row.goal.localizedTitle)
                .font(.subheadline)

            Spacer(minLength: 8)

            Text(verbatim: amount(row))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Image(systemName: row.progress.isAchieved ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(row.progress.isAchieved ? Color.goalDone : .secondary)
        }
        // So a row is a 44pt target in its own right, and so rows do not
        // change height when a clear button appears beside them.
        .frame(minHeight: 44)
        .contentShape(.rect)
    }

    /// A once-a-day goal toggles, like the checkbox it looks like. Anything
    /// that accumulates opens the picker, because "how much" has no answer
    /// the app could guess.
    private func tapped(_ row: DayGoalProgress) {
        switch row.goal.loggingStyle {
        case .single:
            if row.progress.isAchieved {
                clear(row.goal)
            } else {
                log(1, for: row.goal)
            }
        case .incremental:
            entering = row.goal
        }
    }

    private func log(_ amount: Decimal, for goal: Goal) {
        let wasAchieved = model.progress(for: goal, on: day).isAchieved
        withAnimation(Motion.animation(.snappy, reduceMotion: reduceMotion)) {
            model.log(amount, for: goal, on: day)
        }

        guard model.failure == nil else { return }
        // No two-beat celebration here even when the day is finished off:
        // that one belongs to finishing *today*, not to tidying up a
        // Tuesday three weeks ago.
        Haptics.play(model.progress(for: goal, on: day).isAchieved && !wasAchieved ? .completed : .logged)
    }

    private func clear(_ goal: Goal) {
        withAnimation(Motion.animation(.snappy, reduceMotion: reduceMotion)) {
            model.clearDay(for: goal, on: day)
        }
        if model.failure == nil { Haptics.play(.reset) }
    }

    /// Spoken as one sentence. Without this the row reads as four separate
    /// elements — a symbol name, a title, "17 min of 20 min", and a circle —
    /// and the tick, which is the whole answer, is the least obvious of them.
    private func accessibilityLabel(_ row: DayGoalProgress) -> String {
        let state = row.progress.isAchieved
            ? String(localized: "Done")
            : String(localized: "Not yet")
        let detail = amount(row)
        return detail.isEmpty
            ? "\(row.goal.localizedTitle), \(state)"
            : "\(row.goal.localizedTitle), \(detail), \(state)"
    }

    private func hint(for row: DayGoalProgress) -> Text {
        if row.goal.loggingStyle == .single {
            return row.progress.isAchieved
                ? Text("Clears this day")
                : Text("Marks this day done")
        }
        return Text("Adds an amount to this day")
    }

    private func amount(_ row: DayGoalProgress) -> String {
        // A once-a-day goal has no interesting number — the tick is the answer.
        guard row.goal.loggingStyle != .single else { return "" }
        let done = MeasureFormatter.short(row.progress.total, measure: row.goal.measure)
        let target = MeasureFormatter.short(row.progress.target, measure: row.goal.measure)
        return String(localized: "\(done) of \(target)")
    }
}
