import Foundation
import PatchCore

/// Fetches what Apple Health knows and asks the planner what to write.
///
/// Sits between ``HealthKitReader`` (numbers, no decisions) and
/// ``HealthImportPlanner`` (decisions, no numbers) so that neither has to know
/// about the other. It holds exactly one piece of policy of its own — how far
/// back to look — and nothing else.
@MainActor
struct HealthImporter {
    /// How many days back an import reaches.
    ///
    /// Not "since the goal was created": that would re-query a year of history
    /// on every launch to find the one day that changed. A week covers a
    /// holiday away from the phone, a flight, or simply not opening the app,
    /// which is all this needs to catch up from. Days older than that are
    /// settled, and the planner would write nothing for them anyway.
    static let backfillDays = 7

    let reader: any HealthReading
    let calendar: Calendar

    /// The entries to log so every Health-linked goal matches Health.
    ///
    /// Queries once per *source*, not once per goal: two goals both reading
    /// steps are one question to HealthKit, asked once.
    ///
    /// A source that fails is skipped rather than failing the whole import.
    /// Health being briefly unreadable should cost the user the goals that
    /// depend on it, not the ones that do not.
    func pendingEntries(goals: [Goal], entries: [Entry], now: Date = .now) async -> [Entry] {
        let linked = goals.filter { !$0.isArchived && $0.healthSource != nil }
        guard !linked.isEmpty, reader.isAvailable else { return [] }

        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(Self.backfillDays - 1), to: today) ?? today
        // End of today, so today's own samples are inside the range.
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now

        var pending: [Entry] = []
        for source in Set(linked.compactMap(\.healthSource)).sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let totals = try? await reader.dailyTotals(
                for: source, from: start, to: end, calendar: calendar
            ) else { continue }

            for goal in linked where goal.healthSource == source {
                pending += HealthImportPlanner.entries(
                    importing: totals,
                    into: goal,
                    // Entries written earlier in this same loop count: two
                    // goals on one source are independent, but a goal must
                    // see its own pending delta if it is ever visited twice.
                    existing: entries + pending,
                    now: now,
                    calendar: calendar
                )
            }
        }
        return pending
    }
}
