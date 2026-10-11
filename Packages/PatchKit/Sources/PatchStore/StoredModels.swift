import Foundation
import PatchCore
import SwiftData

// CloudKit rules, followed from the start even though sync is not switched on:
// every property has a default or is optional, nothing is uniquely constrained,
// and there are no relationships to need inverses. A goal and its entries are
// linked by `goalID` instead. Retrofitting any of this later means a migration;
// obeying it now costs nothing.

@Model
public final class StoredGoal {
    public var id: UUID = UUID()
    public var title: String = ""
    /// Nil once the user renames the goal — see `Goal.titleKey`.
    public var titleKey: String?
    public var symbolName: String = "target"
    public var measureKindRaw: String = MeasureKind.count.rawValue
    public var dailyTarget: Decimal = Decimal.zero
    public var directionRaw: String = Direction.atLeast.rawValue
    public var scheduleIsDaily: Bool = true
    public var scheduleWeekdays: [Int] = []
    public var cumulativeTarget: Decimal?
    public var createdAt: Date = Date()
    /// Split into two optional scalars rather than one embedded value:
    /// CloudKit wants plain, defaulted or optional properties.
    public var reminderHour: Int?
    public var reminderMinute: Int?
    public var archivedAt: Date?

    public init(_ goal: Goal) {
        id = goal.id
        apply(goal)
    }

    public func apply(_ goal: Goal) {
        title = goal.title
        titleKey = goal.titleKey
        symbolName = goal.symbolName
        measureKindRaw = goal.measure.kind.rawValue
        dailyTarget = goal.measure.dailyTarget
        directionRaw = goal.direction.rawValue
        switch goal.schedule {
        case .daily:
            scheduleIsDaily = true
            scheduleWeekdays = []
        case .daysOfWeek(let days):
            scheduleIsDaily = false
            scheduleWeekdays = days.map(\.rawValue).sorted()
        }
        cumulativeTarget = goal.cumulativeTarget
        createdAt = goal.createdAt
        reminderHour = goal.reminder?.hour
        reminderMinute = goal.reminder?.minute
        archivedAt = goal.archivedAt
    }

    /// Converts back to the domain, falling back rather than failing.
    ///
    /// A newer version of the app syncing an unfamiliar measure kind must not
    /// crash an older one reading it. Showing the goal with a sensible default
    /// beats refusing to open the app.
    /// Both halves or neither — a half-written row is not a reminder.
    private var reminder: Reminder? {
        guard let reminderHour, let reminderMinute else { return nil }
        return Reminder(hour: reminderHour, minute: reminderMinute)
    }

    public var domain: Goal {
        Goal(
            id: id,
            title: title,
            titleKey: titleKey,
            symbolName: symbolName,
            measure: Measure(
                kind: MeasureKind(rawValue: measureKindRaw) ?? .count,
                dailyTarget: dailyTarget
            ),
            direction: Direction(rawValue: directionRaw) ?? .atLeast,
            schedule: scheduleIsDaily
                ? .daily
                : .daysOfWeek(Set(scheduleWeekdays.compactMap(Weekday.init(rawValue:)))),
            cumulativeTarget: cumulativeTarget,
            createdAt: createdAt,
            reminder: reminder,
            archivedAt: archivedAt
        )
    }
}

@Model
public final class StoredEntry {
    public var id: UUID = UUID()
    public var goalID: UUID = UUID()
    public var amount: Decimal = Decimal.zero
    public var loggedAt: Date = Date()
    public var note: String?

    public init(_ entry: Entry) {
        id = entry.id
        goalID = entry.goalID
        amount = entry.amount
        loggedAt = entry.loggedAt
        note = entry.note
    }

    public var domain: Entry {
        Entry(id: id, goalID: goalID, amount: amount, loggedAt: loggedAt, note: note)
    }
}
