import PatchCore
import SwiftUI

struct CalendarScreen: View {
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

    /// Colour is the only thing carrying meaning in the grid, so it is spelled
    /// out rather than left to be guessed.
    private var legend: some View {
        HStack(spacing: 18) {
            ForEach(LegendItem.all) { item in
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

    static var all: [LegendItem] {
        [
            LegendItem(id: "done", title: String(localized: "All done"), color: .accentColor),
            LegendItem(id: "partial", title: String(localized: "Some done"),
                       color: Color.accentColor.opacity(0.35)),
            LegendItem(id: "missed", title: String(localized: "Missed"), color: .orange.opacity(0.7))
        ]
    }
}

/// Month name, with an arrow either side.
private struct MonthBar: View {
    @Bindable var model: CalendarModel

    var body: some View {
        HStack(spacing: 10) {
            Button { withAnimation(.snappy) { model.step(by: -1) } } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(Text("Previous month"))

            Spacer(minLength: 0)

            Text(verbatim: model.monthTitle)
                .font(.headline)
                .contentTransition(.numericText())

            Spacer(minLength: 0)

            Button { withAnimation(.snappy) { model.step(by: 1) } } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel(Text("Next month"))
            .disabled(!model.canStepForward)
        }
        .buttonStyle(.plain)
        .font(.headline)
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
                            guard day.isInMonth, !day.isFuture else { return }
                            withAnimation(.snappy) {
                                model.selectedDay = isSelected(day) ? nil : day.date
                            }
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
                        isSelected ? Color.primary : (day.isToday ? Color.accentColor : .clear),
                        lineWidth: isSelected ? 2 : 1.5
                    )
            }
            .opacity(day.isInMonth ? 1 : 0.25)
            .accessibilityElement()
            .accessibilityLabel(label)
    }

    private var fill: Color {
        guard day.isInMonth, !day.isFuture, day.hasAnything else { return .clear }
        if day.isComplete { return .accentColor }
        if day.summary.completed > 0 { return .accentColor.opacity(0.18 + 0.5 * day.fraction) }
        // Today is not a failure until it is over.
        return day.isToday ? .clear : .orange.opacity(0.45)
    }

    private var foreground: Color {
        day.isComplete ? .white : .primary
    }

    private var label: Text {
        let date = Text(day.date, format: .dateTime.weekday(.wide).day().month(.wide))
        guard day.isInMonth, !day.isFuture, day.hasAnything else { return date }
        return Text("\(day.summary.completed) of \(day.summary.scheduled) goals done") + Text(verbatim: ", ") + date
    }
}

/// What happened on the day the user tapped.
private struct SelectedDayCard: View {
    @Bindable var model: CalendarModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(model.selectedDay ?? .now, format: .dateTime.weekday(.wide).day().month(.wide))
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
                    HStack(spacing: 12) {
                        Image(systemName: row.goal.symbolName)
                            .font(.footnote)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 26, height: 26)
                            .background(Color(uiColor: .tertiarySystemFill), in: .circle)

                        Text(verbatim: row.goal.localizedTitle)
                            .font(.subheadline)

                        Spacer(minLength: 8)

                        Text(verbatim: amount(row))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Image(systemName: row.progress.isAchieved ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(row.progress.isAchieved ? Color.green : .secondary)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
    }

    private func amount(_ row: DayGoalProgress) -> String {
        let kind = row.goal.measure.kind
        // A once-a-day goal has no interesting number — the tick is the answer.
        guard row.goal.loggingStyle != .single else { return "" }
        let done = MeasureFormatter.short(row.progress.total, kind: kind)
        let target = MeasureFormatter.short(row.progress.target, kind: kind)
        return String(localized: "\(done) of \(target)")
    }
}
