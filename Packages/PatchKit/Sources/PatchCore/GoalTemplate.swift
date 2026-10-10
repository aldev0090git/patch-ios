import Foundation

/// A ready-made goal offered during onboarding.
///
/// Carries a localisation *key* rather than a display string: onboarding is the
/// first thing a user sees and it ships in English, Ukrainian and Russian, so a
/// hard-coded English title here would be a bug that is awkward to unpick later.
public struct GoalTemplate: Identifiable, Hashable, Sendable {
    public let id: String
    /// Key resolved against the app's String Catalog by the presentation layer.
    public let titleKey: String
    public let symbolName: String
    public let measure: Measure
    public let direction: Direction
    public let schedule: Schedule
    public let cumulativeTarget: Decimal?

    public init(
        id: String,
        titleKey: String,
        symbolName: String,
        measure: Measure,
        direction: Direction = .atLeast,
        schedule: Schedule = .daily,
        cumulativeTarget: Decimal? = nil
    ) {
        self.id = id
        self.titleKey = titleKey
        self.symbolName = symbolName
        self.measure = measure
        self.direction = direction
        self.schedule = schedule
        self.cumulativeTarget = cumulativeTarget
    }

    /// Builds a real goal from this template.
    ///
    /// `title` is passed in already localised — the domain layer has no opinion
    /// about which language the user reads.
    public func makeGoal(title: String, createdAt: Date = .now) -> Goal {
        Goal(
            title: title,
            symbolName: symbolName,
            measure: measure,
            direction: direction,
            schedule: schedule,
            cumulativeTarget: cumulativeTarget,
            createdAt: createdAt
        )
    }
}

/// The goals offered on first launch.
///
/// Targets here are deliberately gentle — 20 push-ups rather than 100. The job
/// of onboarding is to get someone to succeed on day one, not to show off the
/// app's range. Every one of these is editable before it is created.
public enum GoalTemplateCatalog {
    public static let read = GoalTemplate(
        id: "read",
        titleKey: "template.read",
        symbolName: "book",
        measure: .minutes(20)
    )

    public static let pushUps = GoalTemplate(
        id: "push_ups",
        titleKey: "template.pushUps",
        symbolName: "figure.strengthtraining.functional",
        measure: .times(20, quickAdd: 5)
    )

    public static let water = GoalTemplate(
        id: "water",
        titleKey: "template.water",
        symbolName: "drop",
        measure: .millilitres(2000)
    )

    public static let steps = GoalTemplate(
        id: "steps",
        titleKey: "template.steps",
        symbolName: "figure.walk",
        measure: .steps(10_000)
    )

    public static let saveMoney = GoalTemplate(
        id: "save_money",
        titleKey: "template.saveMoney",
        symbolName: "banknote",
        measure: .money(100, quickAdd: 50),
        cumulativeTarget: 10_000
    )

    /// Confirmed once a day rather than tracked as a running count of slips.
    ///
    /// Modelled as "reach 1 confirmation" rather than "stay at zero
    /// cigarettes". Staying at zero would mean the day is a success from
    /// midnight and the only available action is admitting a lapse, which
    /// gives the user a button that undoes their own goal. Affirming the day
    /// reads better and is honest: the tick means you confirmed it.
    public static let quitSmoking = GoalTemplate(
        id: "quit_smoking",
        titleKey: "template.quitSmoking",
        symbolName: "nosign",
        measure: .times(1)
    )

    public static let gym = GoalTemplate(
        id: "gym",
        titleKey: "template.gym",
        symbolName: "dumbbell",
        measure: .times(1),
        schedule: .daysOfWeek([.monday, .wednesday, .friday])
    )

    public static let run = GoalTemplate(
        id: "run",
        titleKey: "template.run",
        symbolName: "figure.run",
        measure: .times(1),
        schedule: .daysOfWeek([.tuesday, .thursday])
    )

    public static let meditate = GoalTemplate(
        id: "meditate",
        titleKey: "template.meditate",
        symbolName: "brain.head.profile",
        measure: .minutes(10)
    )

    /// Every template, in the order onboarding should present them.
    public static let all: [GoalTemplate] = [
        read, pushUps, water, steps, saveMoney, quitSmoking, gym, run, meditate
    ]

    public static func template(id: String) -> GoalTemplate? {
        all.first { $0.id == id }
    }
}
