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
                .containerBackground(.fill.tertiary, for: .widget)
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
        TodayEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        // The gallery preview gets something plausible; a real install gets
        // its own data.
        let snapshot = context.isPreview ? .placeholder : store.read()
        completion(TodayEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = TodayEntry(date: .now, snapshot: store.read())
        // Refreshed when the app writes, not on a schedule — the app calls
        // `reloadAllTimelines` the moment anything changes, which is both
        // faster and cheaper than waking up to re-read an unchanged file.
        // Midnight is the one change the app cannot announce, because it may
        // not be running, so the timeline ends there.
        completion(Timeline(entries: [entry], policy: .after(.nextMidnight)))
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
