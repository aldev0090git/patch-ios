import SwiftUI

/// The long-run target: a total to reach, and optionally a date to reach it
/// by — "read 100 hours", "save 1500 by March".
///
/// Its own file rather than more of ``GoalEditor``, which was pressing
/// against the length the linter allows. It is self-contained: four bindings,
/// a focus binding and a unit label, with no knowledge of the rest of the
/// form.
struct OverallGoalSection: View {
    @Binding var hasOverall: Bool
    @Binding var target: Decimal
    @Binding var hasDeadline: Bool
    @Binding var deadline: Date

    /// The focus state belongs to the editor, so the keyboard toolbar and
    /// the scroll-into-view both see this field.
    var focused: FocusState<GoalEditor.Field?>.Binding

    /// Already formatted by the caller — a currency symbol for money, the
    /// unit name otherwise.
    let unit: String

    var body: some View {
        Section("Overall goal") {
            Toggle("Work toward a total", isOn: $hasOverall)
            if hasOverall {
                HStack {
                    TextField("Total", value: $target, format: .number)
                        .keyboardType(.decimalPad)
                        .focused(focused, equals: .overall)
                    Text(verbatim: unit)
                        .foregroundStyle(.secondary)
                }

                Toggle("By a date", isOn: $hasDeadline)
                if hasDeadline {
                    DatePicker(
                        "Date",
                        selection: $deadline,
                        in: Date.now...,
                        displayedComponents: .date
                    )
                }
            }
        }
    }
}
