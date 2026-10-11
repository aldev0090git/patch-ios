import PatchCore
import SwiftUI

/// Which weekdays a goal runs on.
///
/// Lifted out of `GoalEditor`, which had grown past the length the linter
/// allows. They are self-contained controls and read better on their own.
struct WeekdayPicker: View {
    @Environment(\.themeAccent) private var themeAccent
    @Binding var selection: Set<Weekday>

    var body: some View {
        let calendar = Calendar.current
        // Starts on whichever day this locale starts on, like every other
        // week-shaped thing in the app.
        let ordered = (0..<7).compactMap { offset in
            Weekday(rawValue: (calendar.firstWeekday - 1 + offset) % 7 + 1)
        }

        return HStack(spacing: 6) {
            ForEach(ordered, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(verbatim: calendar.veryShortWeekdaySymbols[day.rawValue - 1])
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            isOn ? themeAccent.opacity(0.2) : Color(uiColor: .tertiarySystemFill),
                            in: .capsule
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Which dates of the month a goal runs on.
///
/// Seven across, so the columns line up with the weekday row above and with
/// the calendar screen's own grid.
struct MonthDayPicker: View {
    @Environment(\.themeAccent) private var themeAccent
    @Binding var selection: Set<Int>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(1...31, id: \.self) { date in
                let isOn = selection.contains(date)
                Button {
                    if isOn { selection.remove(date) } else { selection.insert(date) }
                } label: {
                    Text(date, format: .number)
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(
                            isOn ? themeAccent.opacity(0.2) : Color(uiColor: .tertiarySystemFill),
                            in: .rect(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.vertical, 4)
    }
}
