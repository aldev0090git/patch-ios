import Foundation

/// What the home screen needs to know about today.
///
/// Deliberately a *snapshot* rather than shared access to the database. The
/// obvious way to feed a widget is to move the store into the App Group so
/// both processes can read it, and that would mean migrating the file out of
/// the app's own container — a change that looks exactly like data loss if it
/// goes wrong, for a feature nobody asked to risk their history for.
///
/// A widget cannot do much with a database anyway. It is given a few
/// milliseconds, several times a day, to draw a small rectangle. A handful of
/// pre-computed numbers is what it actually wants, and writing them is cheap
/// enough to do on every change.
public struct WidgetSnapshot: Codable, Hashable, Sendable {
    /// One goal, reduced to what fits on a home screen.
    public struct Item: Codable, Hashable, Sendable, Identifiable {
        public let id: UUID
        public let title: String
        public let symbolName: String
        /// 0...1, clamped. The ring, not the number.
        public let fraction: Double
        public let isAchieved: Bool

        public init(id: UUID, title: String, symbolName: String, fraction: Double, isAchieved: Bool) {
            self.id = id
            self.title = title
            self.symbolName = symbolName
            self.fraction = min(1, max(0, fraction))
            self.isAchieved = isAchieved
        }
    }

    public let date: Date
    public let items: [Item]
    /// The page theme the app is wearing, so the home screen can match it.
    public let theme: PageTheme

    public init(date: Date, items: [Item], theme: PageTheme = .plain) {
        self.date = date
        self.items = items
        self.theme = theme
    }

    /// Hand-written so a snapshot left by an older build still reads. The
    /// file in the shared container outlives any one version of the app, and
    /// a widget that fails to decode shows its "nothing yet" state — which
    /// would look exactly like data loss to whoever is reading it.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        items = try container.decode([Item].self, forKey: .items)
        theme = try container.decodeIfPresent(PageTheme.self, forKey: .theme) ?? .plain
    }

    public var completed: Int { items.count(where: \.isAchieved) }
    public var scheduled: Int { items.count }

    /// The same average the Today header shows — every goal's own progress,
    /// not just the finished ones. A half-done morning should read as moving
    /// rather than as nothing.
    public var fraction: Double {
        guard !items.isEmpty else { return 0 }
        return items.reduce(0) { $0 + $1.fraction } / Double(items.count)
    }

    /// A day with nothing scheduled is not a day you finished — see
    /// `TodayModel.isDayComplete` for why that distinction is worth keeping.
    public var isComplete: Bool { !items.isEmpty && completed == scheduled }

    /// What to do next: the first goal still unfinished, in the order the
    /// app lists them.
    ///
    /// Nil when the day is done or empty — the two cases a widget has to tell
    /// apart from "there is something left", and which it must not render as
    /// a goal with a blank name.
    public var nextUnfinished: Item? {
        items.first { !$0.isAchieved }
    }

    /// Goals still to do. Drives "+2 more" rather than silently hiding them:
    /// a widget that shows four of eight goals and says nothing is lying by
    /// omission, and the owner of the other four has no way to know.
    public var remaining: [Item] {
        items.filter { !$0.isAchieved }
    }

    public static let empty = WidgetSnapshot(date: .distantPast, items: [])

    /// The same day, wearing a different theme. Changing the theme does not
    /// change any of the numbers, so there is no reason to recompute them.
    public func wearing(_ theme: PageTheme) -> WidgetSnapshot {
        WidgetSnapshot(date: date, items: items, theme: theme)
    }
}

extension WidgetSnapshot {
    /// Builds today's snapshot from the real data.
    ///
    /// Titles are resolved by the caller: a template goal carries a key, not a
    /// word, and `PatchCore` has no business knowing the reader's language.
    public static func today(
        goals: [Goal],
        entries: [Entry],
        titles: (Goal) -> String,
        theme: PageTheme = .plain,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> WidgetSnapshot {
        let progress = ProgressCalculator(calendar: calendar)
        let items = goals
            .filter { !$0.isArchived && $0.schedule.isScheduled(on: now, calendar: calendar) }
            .map { goal -> Item in
                let day = progress.progress(for: goal, entries: entries, on: now)
                return Item(
                    id: goal.id,
                    title: titles(goal),
                    symbolName: goal.symbolName,
                    // An allowance fills as it is spent, like everywhere else.
                    fraction: day.budgetUsed ?? day.fraction,
                    isAchieved: day.isAchieved
                )
            }
        return WidgetSnapshot(date: calendar.startOfDay(for: now), items: items, theme: theme)
    }
}

/// Where the app leaves the snapshot and the widget picks it up.
///
/// A file in the shared container rather than `UserDefaults`: a snapshot is a
/// document, it is written whole, and a half-written one should never be read.
/// Writing atomically gives that for free.
public struct WidgetSnapshotStore: Sendable {
    public static let appGroup = "group.com.aldev0090.Patch"
    private static let filename = "today.json"

    private let container: URL?

    public init(appGroup: String = WidgetSnapshotStore.appGroup) {
        container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
        )
    }

    /// For tests, which have no App Group.
    public init(directory: URL) {
        container = directory
    }

    private var url: URL? { container?.appending(path: Self.filename) }

    public func write(_ snapshot: WidgetSnapshot) {
        guard let url else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        // Atomic: the widget must never see half a file.
        try? data.write(to: url, options: .atomic)
    }

    /// `nil` when there is nothing to read — a fresh install, or an app that
    /// has not been opened since the group existed. The widget shows its own
    /// empty state rather than pretending the day is blank.
    public func read() -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}
