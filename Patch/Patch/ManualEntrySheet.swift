import PatchCore
import SwiftUI

/// Manual amount entry, for when none of the three suggestions fits.
///
/// Opens on the smallest amount. Defaulting to the amount still needed sounds
/// helpful but lands the wheel at the very bottom of a long list, which reads
/// as though the picker is stuck and gives you nowhere to scroll down to.
struct ManualEntrySheet: View {
    let goal: Goal
    let onAdd: (Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Decimal

    init(goal: Goal, onAdd: @escaping (Decimal) -> Void) {
        self.goal = goal
        self.onAdd = onAdd
        _selection = State(initialValue: ManualAmounts.options(for: goal.measure).first ?? 1)
    }

    private var options: [Decimal] { ManualAmounts.options(for: goal.measure) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Amount", selection: $selection) {
                    ForEach(options, id: \.self) { amount in
                        Text(verbatim: MeasureFormatter.short(amount, measure: goal.measure))
                            .tag(amount)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            // `localizedTitle`, not `title`: a goal seeded from a template
            // keeps the English word in `title` and carries its key
            // separately, so this sheet was the one screen showing "Read" to
            // a Russian reader.
            .navigationTitle(Text(verbatim: goal.localizedTitle))
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
}
