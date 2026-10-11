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
    /// Only meaningful for a currency goal; nil means the phone's own.
    public var currencyCode: String?
    public var directionRaw: String = Direction.atLeast.rawValue
    public var scheduleIsDaily: Bool = true
    public var scheduleWeekdays: [Int] = []
    /// Non-empty only for a date-of-month schedule, which is how it is told
    /// apart from the other two without adding a discriminator an older build
    /// would not understand.
    public var scheduleMonthDays: [Int] = []
    public var cumulativeTarget: Decimal?
    public var createdAt: Date = Date()
    /// Split into two optional scalars rather than one embedded value:
    /// CloudKit wants plain, defaulted or optional properties.
    /// JSON rather than parallel arrays: CloudKit takes `Data` happily, and
    /// two arrays that must stay the same length is a bug waiting to happen.
    public var targetHistoryData: Data?
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
        currencyCode = goal.measure.currencyCode
        directionRaw = goal.direction.rawValue
        switch goal.schedule {
        case .daily:
            scheduleIsDaily = true
            scheduleWeekdays = []
            scheduleMonthDays = []
        case .daysOfWeek(let days):
            scheduleIsDaily = false
            scheduleWeekdays = days.map(\.rawValue).sorted()
            scheduleMonthDays = []
        case .daysOfMonth(let days):
            scheduleIsDaily = false
            scheduleWeekdays = []
            scheduleMonthDays = days.sorted()
        }
        cumulativeTarget = goal.cumulativeTarget
        createdAt = goal.createdAt
        targetHistoryData = goal.targetHistory.isEmpty
            ? nil
            : try? JSONEncoder().encode(goal.targetHistory)
        reminderHour = goal.reminder?.hour
        reminderMinute = goal.reminder?.minute
        archivedAt = goal.archivedAt
    }

    /// Converts back to the domain, falling back rather than failing.
    ///
    /// A newer version of the app syncing an unfamiliar measure kind must not
    /// crash an older one reading it. Showing the goal with a sensible default
    /// beats refusing to open the app.
    /// Month days win when present, so a row written by a newer build still
    /// reads correctly here and an older row keeps its old meaning.
    private var schedule: Schedule {
        if !scheduleMonthDays.isEmpty { return .daysOfMonth(Set(scheduleMonthDays)) }
        if scheduleIsDaily { return .daily }
        return .daysOfWeek(Set(scheduleWeekdays.compactMap(Weekday.init(rawValue:))))
    }

    /// Unreadable history is dropped rather than fatal: the goal still works,
    /// it just judges every day against its current target, which is exactly
    /// where it stood before this existed.
    private var targetHistory: [TargetChange] {
        guard let targetHistoryData else { return [] }
        return (try? JSONDecoder().decode([TargetChange].self, from: targetHistoryData)) ?? []
    }

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
                dailyTarget: dailyTarget,
                currencyCode: currencyCode
            ),
            direction: Direction(rawValue: directionRaw) ?? .atLeast,
            schedule: schedule,
            cumulativeTarget: cumulativeTarget,
            createdAt: createdAt,
            targetHistory: targetHistory,
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
