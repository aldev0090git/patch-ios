#if DEBUG
import Foundation
import PatchCore

/// Fills the store with a plausible couple of months, for screenshots.
///
/// `#if DEBUG` and behind a launch argument, so it cannot reach a release
/// build and cannot run unless something asks for it by name. Screenshots of
/// an empty app sell nothing, and hand-logging eight weeks is not a thing
/// anyone should do twice.
///
/// Deliberately imperfect: a wall of 100% looks fake and, worse, hides what
/// the app does with a missed day.
enum DemoData {
    static let launchArgument = "-demo-data"

    static var isRequested: Bool {
        CommandLine.arguments.contains(launchArgument)
    }

    static func install(into store: GoalStore, calendar: Calendar = .current) {
        guard (try? store.loadGoals())?.isEmpty ?? false else { return }

        let start = calendar.date(byAdding: .day, value: -62, to: .now) ?? .now

        let read = GoalTemplateCatalog.read.makeGoal(title: "Read", createdAt: start)
        let water = GoalTemplateCatalog.water.makeGoal(title: "Water", createdAt: start)
        let pushUps = GoalTemplateCatalog.pushUps.makeGoal(title: "Push-ups", createdAt: start)
        let gym = GoalTemplateCatalog.gym.makeGoal(title: "Gym", createdAt: start)
        let saving = savingGoal(start: start, calendar: calendar)
        let coffee = coffeeGoal(start: start)

        let goals = [read, water, pushUps, gym, saving]
        for goal in goals + [coffee] { try? store.save(goal) }

        // A fixed generator, so every screenshot run produces the same picture.
        var seed: UInt64 = 20_261_011
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(UInt64.max >> 11)
        }

        for dayOffset in stride(from: 62, through: 1, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now) else { continue }

            for goal in goals where goal.schedule.isScheduled(on: date, calendar: calendar) {
                // Roughly three days in four, so streaks are real and gaps are
                // real. The calendar needs both to be worth looking at.
                guard next() < 0.76 else { continue }
                log(goal: goal, on: date, into: store, calendar: calendar, random: next)
            }
        }

        // Coffee runs after the others so that adding it did not shift the
        // random sequence the rest of the history was generated from.
        for dayOffset in stride(from: 62, through: 1, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now) else { continue }
            // Usually one or two, occasionally a third — so the calendar shows
            // real days over the limit rather than a flawless run.
            let cups = next() < 0.8 ? Int(next() * 2) + 1 : 3
            for cup in 0..<cups {
                let at = calendar.date(bySettingHour: 8 + cup * 4, minute: 0, second: 0, of: date)
                    ?? calendar.startOfDay(for: date)
                try? store.log(Entry(goalID: coffee.id, amount: 1, loggedAt: at))
            }
        }

        // Today, deliberately part-finished: the Today screen is at its most
        // informative mid-morning, not at midnight or bedtime.
        try? store.log(Entry(goalID: read.id, amount: 600, loggedAt: .now))
        try? store.log(Entry(goalID: water.id, amount: 1000, loggedAt: .now))
        try? store.log(Entry(goalID: pushUps.id, amount: 20, loggedAt: .now))
        try? store.log(Entry(goalID: coffee.id, amount: 1, loggedAt: .now))
    }

    private static func log(
        goal: Goal,
        on date: Date,
        into store: GoalStore,
        calendar: Calendar,
        random: () -> Double
    ) {
        let target = goal.measure.dailyTarget

        switch goal.measure.kind {
        case .duration, .volume:
            // Logged in pieces through the day, as these actually are.
            //
            // Anchored to fixed hours rather than offset from the seeding
            // time. `date` is "now, n days ago", so adding three hours per
            // piece pushed yesterday's last piece into today whenever the app
            // was seeded after six in the evening — and today's totals then
            // depended on the clock. Morning, midday, late afternoon always
            // land inside the day they belong to.
            let pieces = Int(random() * 2) + 2
            let each = target / Decimal(pieces)
            for piece in 0..<pieces {
                let at = calendar.date(
                    bySettingHour: 8 + piece * 4, minute: 0, second: 0, of: date
                ) ?? calendar.startOfDay(for: date)
                try? store.log(Entry(goalID: goal.id, amount: each, loggedAt: at))
            }
        default:
            let at = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)
                ?? calendar.startOfDay(for: date)
            try? store.log(Entry(goalID: goal.id, amount: target, loggedAt: at))
        }
    }

    /// The only goal with a long-run target and a date to reach it by, and the
    /// only one on a day-of-month schedule — both are shapes no template
    /// covers, and both show up on the statistics screen.
    private static func savingGoal(start: Date, calendar: Calendar) -> Goal {
        var saving = Goal(
            title: "Save",
            titleKey: GoalTemplateCatalog.saveMoney.titleKey,
            symbolName: "banknote",
            measure: .money(4000, currencyCode: "UAH"),
            schedule: .daysOfMonth([1, 15]),
            cumulativeTarget: 60_000,
            createdAt: start
        )
        saving.cumulativeDeadline = calendar.date(byAdding: .month, value: 4, to: .now)
        return saving
    }

    /// An allowance, which is the one goal shape the other five do not cover:
    /// `atMost`, where being inside the limit is not the same as being
    /// finished for the day. The Today card got that wrong for a release, and
    /// nothing in the demo data would have shown it.
    private static func coffeeGoal(start: Date) -> Goal {
        Goal(
            title: "Coffee",
            // Every other seeded goal carries a key so it follows the phone's
            // language; this one did not, and sat in English on an otherwise
            // fully translated screen. It is demo-only, hence `demo.` rather
            // than `template.` — there is no coffee template.
            titleKey: "demo.coffee",
            symbolName: "cup.and.saucer",
            measure: .times(2),
            direction: .atMost,
            createdAt: start
        )
    }

}
#endif
