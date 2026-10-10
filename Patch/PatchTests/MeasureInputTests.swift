import Foundation
import PatchCore
import Testing
@testable import Patch

@Suite("Target entry")
struct MeasureInputTests {
    @Test("Minutes typed in the form become seconds in the domain")
    func minutesBecomeSeconds() {
        #expect(MeasureInput.toCanonical(20, kind: .duration) == 1200)
        #expect(MeasureInput.fromCanonical(1200, kind: .duration) == 20)
    }

    @Test("Kinds stored in their own unit pass straight through")
    func otherKindsPassThrough() {
        for kind in [MeasureKind.count, .volume, .distance, .currency] {
            #expect(MeasureInput.toCanonical(500, kind: kind) == 500)
            #expect(MeasureInput.fromCanonical(500, kind: kind) == 500)
        }
    }

    @Test("A value survives a trip through the form and back")
    func conversionRoundTrips() {
        for kind in MeasureKind.allCases {
            let entered = Decimal(37)
            let stored = MeasureInput.toCanonical(entered, kind: kind)
            #expect(MeasureInput.fromCanonical(stored, kind: kind) == entered)
        }
    }

    @Test("Editing an existing goal shows the number that was typed in")
    func editingShowsTheOriginalNumber() {
        // The form must not show "1200" for a goal created as 20 minutes.
        let goal = Goal(title: "Read", measure: .minutes(20))
        let shown = MeasureInput.fromCanonical(goal.measure.dailyTarget, kind: goal.measure.kind)

        #expect(shown == 20)
    }

    @Test("Every kind has a unit label and a name")
    func labelsExist() {
        for kind in MeasureKind.allCases {
            #expect(!MeasureInput.unitLabel(for: kind).isEmpty)
            #expect(!MeasureInput.kindLabel(for: kind).isEmpty)
        }
    }
}
