import PatchCore
import SwiftUI

/// The app's shell.
///
/// A tab bar rather than a button on Today pushing a second screen: Today and
/// Statistics are peers, both are places you return to, and neither is a
/// detail of the other. It also leaves the calendar somewhere obvious to go.
struct RootView: View {
    let store: GoalStore

    var body: some View {
        TabView {
            Tab("Today", systemImage: "checkmark.circle") {
                ContentView(model: TodayModel(store: store))
            }

            Tab("Statistics", systemImage: "chart.bar") {
                StatisticsView(model: StatisticsModel(store: store))
            }
        }
    }
}
