import PatchCore
import SwiftUI
import WidgetKit

/// Today's progress on the home screen.
///
/// Reads a snapshot the app leaves in the shared container rather than
/// touching the database — see ``WidgetSnapshot`` for why. That also means
/// this never blocks: the worst case is a file that is not there yet, which
/// has its own state rather than a pretend empty day.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
            TodayWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    // `.fill.tertiary` before this, which is the system's
                    // default-looking grey. The theme replaces it on the
                    // home screen and leaves the Lock Screen alone.
                    WidgetBackground(theme: entry.snapshot?.theme ?? .plain)
                }
        }
        .configurationDisplayName("Today")
        .description("How today is going, at a glance.")
        // Lock Screen families read the same snapshot and cost nothing
        // extra: no database, no migration, no additional work for the app.
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    /// `nil` before the app has ever written one.
    let snapshot: WidgetSnapshot?
}

struct TodayProvider: TimelineProvider {
    private let store = WidgetSnapshotStore()

    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: .placeholder.wearing(theme))
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        // The gallery preview gets something plausible; a real install gets
        // its own data. Either way it wears the theme the app is wearing —
        // picking a widget that looks nothing like what you will get once it
        // lands on the home screen is a poor way to choose one.
        let snapshot = context.isPreview
            ? .placeholder.wearing(theme)
            : store.read()?.days.first
        completion(TodayEntry(date: .now, snapshot: snapshot))
    }

    /// The real snapshot's theme, used to dress the made-up one. Falls back
    /// to plain before the app has ever written, which is also when there is
    /// no theme to honour.
    private var theme: PageTheme {
        store.read()?.days.first?.theme ?? .plain
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        // One entry per day the app left behind. The first renders now; each
        // later one is dated at that day's midnight, so the widget turns over
        // on its own rather than waiting for a refresh it does not control.
        //
        // It used to send a single entry with `.after(.nextMidnight)`, which
        // only *asks* for a new timeline after midnight. WidgetKit grants
        // those on a budget, so the widget could sit on yesterday's numbers
        // for hours until the app was opened.
        let calendar = Calendar.current
        let days = store.read()?.days ?? []
        guard !days.isEmpty else {
            let entry = TodayEntry(date: .now, snapshot: nil)
            return completion(Timeline(entries: [entry], policy: .after(.nextMidnight)))
        }

        let entries = days.enumerated().map { index, snapshot in
            TodayEntry(
                date: index == 0 ? .now : calendar.startOfDay(for: snapshot.date),
                snapshot: snapshot
            )
        }
        // `.atEnd`: ask again once the last day has been shown. The app
        // reloads on every write anyway, so this is only the fallback for a
        // phone nobody has opened in days.
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

private extension Date {
    static var nextMidnight: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))
            ?? .now.addingTimeInterval(3600)
    }
}

extension WidgetSnapshot {
    /// What the widget gallery shows before anyone has data. Deliberately
    /// part-finished: a wall of ticks would promise a different app.
    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(date: .now, items: [
            Item(id: UUID(), title: "Read", symbolName: "book", fraction: 1, isAchieved: true),
            Item(id: UUID(), title: "Water", symbolName: "drop", fraction: 0.5, isAchieved: false),
            Item(id: UUID(), title: "Steps", symbolName: "figure.walk", fraction: 0.3, isAchieved: false)
        ])
    }
}
