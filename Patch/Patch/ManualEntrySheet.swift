import PatchCore
import SwiftUI

/// Manual amount entry, for when none of the three suggestions fits.
///
/// Opens on the amount still needed to finish the day rather than on the
/// smallest option, since that is overwhelmingly the value people want.
struct ManualEntrySheet: View {
    let goal: Goal
    let remaining: Decimal
    let onAdd: (Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Decimal

    init(goal: Goal, remaining: Decimal, onAdd: @escaping (Decimal) -> Void) {
        self.goal = goal
        self.remaining = remaining
        self.onAdd = onAdd
        let options = ManualAmounts.options(for: goal.measure)
        let preferred = remaining > .zero ? remaining : goal.measure.dailyTarget
        _selection = State(initialValue: Self.nearest(to: preferred, in: options))
    }

    private var options: [Decimal] { ManualAmounts.options(for: goal.measure) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Amount", selection: $selection) {
                    ForEach(options, id: \.self) { amount in
                        Text(MeasureFormatter.short(amount, kind: goal.measure.kind))
                            .tag(amount)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .navigationTitle(goal.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(selection)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(300)])
    }

    /// The closest offered amount, so the picker never opens on a value it
    /// cannot show.
    private static func nearest(to value: Decimal, in options: [Decimal]) -> Decimal {
        options.min { lhs, rhs in
            (lhs - value).magnitude < (rhs - value).magnitude
        } ?? value
    }
}
