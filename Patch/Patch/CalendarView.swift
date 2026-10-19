import PatchCore
import SwiftUI

struct CalendarScreen: View {
    @Environment(\.themeAccent) private var themeAccent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State var model: CalendarModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MonthGrid(model: model)
                    if model.selectedDay != nil {
                        SelectedDayCard(model: model)
                            .transition(Motion.transition(
                                .opacity.combined(with: .move(edge: .bottom)),
                                reduceMotion: reduceMotion
                            ))
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: CalendarModel

    var body: some View {
        HStack(spacing: 10) {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left")
                    // 44pt is the smallest target iOS expects, and a chevron
                    // draws at about 9x14. The frame is the hit area; the
                    // glyph stays the size it was.
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(Text("Previous month"))

            Spacer(minLength: 0)

            Text(verbatim: model.monthTitle)
                .font(.headline)
                .contentTransition(.numericText())

            Spacer(minLength: 0)

            Button { step(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(Text("Next month"))
            .disabled(!model.canStepForward)
        }
        .buttonStyle(.plain)
        .font(.headline)
    }

    private func step(_ delta: Int) {
        withAnimation(Motion.animation(.snappy, reduceMotion: reduceMotion)) {
            model.step(by: delta)
        }
        Haptics.play(.selection)
    }
}

private struct MonthGrid: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                            withAnimation(Motion.animation(.snappy, reduceMotion: reduceMotion)) {
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
        // A day borrowed from a neighbouring month carries no verdict here,
        // so it gets no fill rather than a faded one.
        guard day.isInMonth, !day.isFuture, day.hasAnything else { return .clear }
        if day.isComplete { return themeAccent }
        if day.summary.completed > 0 { return themeAccent.opacity(0.18 + 0.5 * day.fraction) }
        // Today is not a failure until it is over.
        return day.isToday ? .clear : Color.goalMissed.opacity(0.45)
    }

    private var foreground: Color {
        if day.isComplete { return .white }
        // `.secondary` rather than `.primary` at 25% opacity, which is how
        // the borrowed days used to be dimmed. A quarter-strength label
        // fails contrast outright; `.secondary` is a system colour that is
        // guaranteed to pass and still reads as "not this month".
        return day.isInMonth ? .primary : .secondary
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
