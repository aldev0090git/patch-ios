import Foundation
import PatchCore
import Testing
@testable import Patch

/// The calendar is never left with nothing chosen.
///
/// Its own suite rather than more of ``CalendarModelTests``: this is one
/// rule, stated three ways — on opening, on paging to a month that holds
/// today, and on paging to one that does not.
@Suite("Calendar selection")
struct CalendarSelectionTests {
    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }

    @MainActor
    private func model() -> CalendarModel {
        let model = CalendarModel(store: InMemoryGoalStore(goals: [], entries: []),
                                  calendar: calendar())
        model.load()
        return model
    }

    @MainActor
    @Test("Changing month moves the selection to the first of the new one")
    func steppingReselects() {
        let model = model()
        model.selectedDay = calendar().startOfDay(for: .now)
        model.step(by: -1)

        let start = calendar().dateInterval(of: .month, for: model.month)?.start
        #expect(model.selectedDay == start.map { calendar().startOfDay(for: $0) })
    }

    @MainActor
    @Test("Coming back to this month lands on today, not the first")
    func steppingBackSelectsToday() {
        let model = model()
        model.step(by: -1)
        model.step(by: 1)

        #expect(model.selectedDay == calendar().startOfDay(for: .now))
    }

    @MainActor
    @Test("A month is never left with nothing selected")
    func somethingIsAlwaysSelected() {
        let model = model()
        model.load()
        #expect(model.selectedDay != nil)

        for _ in 0..<6 {
            model.step(by: -1)
            #expect(model.selectedDay != nil)
        }
    }
}
