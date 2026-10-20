import Foundation

/// Turns "Apple Health says you walked 7 432 steps today" into entries.
///
/// All of the thinking in the Health feature lives here, and none of HealthKit
/// does. The framework is unavailable on the simulator and unreachable from a
/// test, so the part that decides *what to write* is kept separate from the
/// part that reads the numbers — the same split as ``ReminderPlanner`` and the
/// notification scheduler.
///
/// ## Why deltas
///
/// Entries are immutable, and Health's figure for today climbs all day. The
/// planner therefore never writes a day's total; it writes the **difference**
/// between what Health now says and what this goal has already imported, so a
/// day that goes 2 000 → 5 000 → 7 432 steps lands as three entries summing to
/// 7 432 rather than three entries summing to 14 432.
///
/// Only ``EntrySource/health`` entries count toward "already imported". A tap
/// the user made by hand is theirs: someone who walked on a treadmill the
/// phone was not in, and logged it, must not watch the next refresh cancel it
/// out. The two sources add up, which is the honest reading of "I did both".
///
/// A **negative** delta is legal and deliberate. Deleting a workout in the
/// Health app lowers the day's total, and a goal that then stayed high would
/// be claiming something the user has just said did not happen.
public enum HealthImportPlanner {
    /// The entries to insert so this goal matches what Health reports.
    ///
    /// Returns an empty array for every reason it should: the goal is not
    /// linked to Health, it is archived, the kinds disagree, nothing changed.
    /// Callers are expected to log whatever comes back and nothing else.
    ///
    /// - Parameters:
    ///   - dailyTotals: Health's total per day, in the goal's canonical unit.
    ///     Keys are normalised here, so any instant within a day will do.
    ///   - goal: The goal to fill.
    ///   - existing: Entries already stored. Entries belonging to other goals
    ///     are ignored, so callers may pass everything they have.
    public static func entries(
        importing dailyTotals: [Date: Decimal],
        into goal: Goal,
        existing: [Entry],
        now: Date,
        calendar: Calendar
    ) -> [Entry] {
        guard let source = goal.healthSource, !goal.isArchived else { return [] }

        // A mismatch means a goal's measure was changed to a kind its source
        // cannot fill. Refusing beats writing metres into a count — the editor
        // clears the source on such a change, and this is the backstop for a
        // goal that arrives from sync having missed it.
        guard source.measureKind == goal.measure.kind else { return [] }

        let today = calendar.startOfDay(for: now)
        let created = calendar.startOfDay(for: goal.createdAt)

        var alreadyImported: [Date: Decimal] = [:]
        for entry in existing where entry.goalID == goal.id && entry.source == .health {
            alreadyImported[calendar.startOfDay(for: entry.loggedAt), default: .zero] += entry.amount
        }

        // Normalised first: two instants on the same day must not become two
        // entries, each cancelling out the other's delta.
        var totalsByDay: [Date: Decimal] = [:]
        for (instant, total) in dailyTotals {
            totalsByDay[calendar.startOfDay(for: instant), default: .zero] += total
        }

        return totalsByDay.keys.sorted().compactMap { day -> Entry? in
            guard day <= today, day >= created else { return nil }
            guard goal.schedule.isScheduled(on: day, calendar: calendar) else { return nil }

            let delta = (totalsByDay[day] ?? .zero) - (alreadyImported[day] ?? .zero)
            guard delta != .zero else { return nil }

            return Entry(
                goalID: goal.id,
                amount: delta,
                loggedAt: timestamp(for: day, today: today, now: now, calendar: calendar),
                source: .health
            )
        }
    }

    /// Today is stamped now; an earlier day is stamped midday.
    ///
    /// Midday for the same reason backdating uses it — a flight across a time
    /// zone must not drag a day's entries into the day before. Today keeps the
    /// real instant so the order of the day's log still reads correctly.
    private static func timestamp(
        for day: Date,
        today: Date,
        now: Date,
        calendar: Calendar
    ) -> Date {
        guard day != today else { return now }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }
}
