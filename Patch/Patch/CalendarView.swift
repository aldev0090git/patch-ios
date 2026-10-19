import PatchCore
import SwiftUI

struct CalendarScreen: View {
    @Environment(\.themeAccent) private var themeAccent
    @State var model: CalendarModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MonthGrid(model: model)
                    if model.selectedDay != nil {
                        SelectedDayCard(model: model)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        legend
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                MonthBar(model: model)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .background(.bar)
            }
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

    /// Colour is the only thing carrying meaning in the grid, so it is spelled
    /// out rather than left to be guessed.
    private var legend: some View {
        HStack(spacing: 18) {
            ForEach(LegendItem.all(accent: themeAccent)) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 10, height: 10)
                    Text(verbatim: item.title)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }
}

private struct LegendItem: Identifiable {
    let id: String
    let title: String
    let color: Color

    /// Takes the accent rather than reading it: this is a plain value type,
    /// and only a `View` can see the environment.
    static func all(accent: Color) -> [LegendItem] {
        [
            LegendItem(id: "done", title: String(localized: "All done"), color: accent),
            LegendItem(id: "partial", title: String(localized: "Some done"),
                       color: accent.opacity(0.35)),
            LegendItem(id: "missed", title: String(localized: "Missed"),
                       color: Color.goalMissed.opacity(0.7))
        ]
    }
}

/// Month name, with an arrow either side.
private struct MonthBar: View {
    @Bindable var model: CalendarModel

    var body: some View {
        HStack(spacing: 10) {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(Text("Previous month"))

            Spacer(minLength: 0)

            Text(verbatim: model.monthTitle)
                .font(.headline)
                .contentTransition(.numericText())

            Spacer(minLength: 0)

            Button { step(1) } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel(Text("Next month"))
            .disabled(!model.canStepForward)
        }
        .buttonStyle(.plain)
        .font(.headline)
    }

    private func step(_ delta: Int) {
        withAnimation(.snappy) { model.step(by: delta) }
        Haptics.play(.selection)
    }
}

private struct MonthGrid: View {
    @Bindable var model: CalendarModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 6) {
                // By offset, not by value: two weekdays can share a very
                // short symbol (T, T in English; С, С in Russian).
                ForEach(Array(model.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(verbatim: symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(model.days) { day in
                    DayCell(day: day, isSelected: isSelected(day))
                        .onTapGesture {
                            // A tap on a blank or future cell is not a
                            // selection, so it gets no acknowledgement either —
                            // a tick there would claim something happened.
                            guard day.isInMonth, !day.isFuture else { return }
                            withAnimation(.snappy) {
                                model.selectedDay = isSelected(day) ? nil : day.date
                            }
                            Haptics.play(.selection)
                        }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
    }

    private func isSelected(_ day: CalendarDay) -> Bool {
        model.selectedDay == day.date
    }
}

/// One day.
///
/// The fill says how much of the day was done; a ring says "today". Days from
/// the neighbouring months are dimmed rather than removed, so the weeks stay
/// aligned under their headings.
private struct DayCell: View {
    @Environment(\.themeAccent) private var themeAccent
    let day: CalendarDay
    let isSelected: Bool

    var body: some View {
        // The square comes from an empty shape, with the number overlaid on
        // top. Sizing the square from the text instead squeezes it until
        // two-digit days truncate to an ellipsis.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Text(day.date, format: .dateTime.day())
                    .font(.callout.weight(day.isToday ? .bold : .regular))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(foreground)
            }
            .background(fill, in: .circle)
            .overlay {
                Circle()
                    .strokeBorder(
                        isSelected ? Color.primary : (day.isToday ? themeAccent : .clear),
                        lineWidth: isSelected ? 2 : 1.5
                    )
            }
            .opacity(day.isInMonth ? 1 : 0.25)
            .accessibilityElement()
            .accessibilityLabel(label)
            // Only the month's own days are identified: the cells borrowed
            // from the neighbouring months would collide with them, and a
            // test that taps "the 1st" must not land on next month's.
            .accessibilityIdentifier(day.isInMonth ? "calendar.day.\(dayNumber)" : "")
    }

    private var dayNumber: Int {
        Calendar.current.component(.day, from: day.date)
    }

    private var fill: Color {
        guard day.isInMonth, !day.isFuture, day.hasAnything else { return .clear }
        if day.isComplete { return themeAccent }
        if day.summary.completed > 0 { return themeAccent.opacity(0.18 + 0.5 * day.fraction) }
        // Today is not a failure until it is over.
        return day.isToday ? .clear : Color.goalMissed.opacity(0.45)
    }

    private var foreground: Color {
        day.isComplete ? .white : .primary
    }

    private var label: Text {
        // Assembled as a `String` and handed over verbatim rather than built
        // by `Text` + `Text`, which is deprecated, and rather than as one
        // interpolated key, which would add "%@, %@" to the catalog for three
        // translators to puzzle over. A comma is not a sentence.
        let date = day.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard day.isInMonth, !day.isFuture, day.hasAnything else { return Text(verbatim: date) }
        let summary = String(localized: "\(day.summary.completed) of \(day.summary.scheduled) goals done")
        return Text(verbatim: "\(summary), \(date)")
    }
}

/// What happened on the day the user tapped — and the only place a day that
/// has already passed can be corrected.
///
/// Tapping a row logs against *that* day rather than today. The controls are
/// the ones the goal already has on the Today screen — a once-a-day goal
/// toggles, an incremental one opens the same amount picker — because a goal
/// should not behave differently depending on which screen you reached it
/// from.
private struct SelectedDayCard: View {
    @Environment(\.themeAccent) private var themeAccent
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
                    withAnimation(.snappy) { model.selectedDay = nil }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
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

            Text(verbatim: row.goal.localizedTitle)
                .font(.subheadline)

            Spacer(minLength: 8)

            Text(verbatim: amount(row))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Image(systemName: row.progress.isAchieved ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(row.progress.isAchieved ? Color.goalDone : .secondary)
        }
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
        withAnimation(.snappy) { model.log(amount, for: goal, on: day) }

        guard model.failure == nil else { return }
        // No two-beat celebration here even when the day is finished off:
        // that one belongs to finishing *today*, not to tidying up a
        // Tuesday three weeks ago.
        Haptics.play(model.progress(for: goal, on: day).isAchieved && !wasAchieved ? .completed : .logged)
    }

    private func clear(_ goal: Goal) {
        withAnimation(.snappy) { model.clearDay(for: goal, on: day) }
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
