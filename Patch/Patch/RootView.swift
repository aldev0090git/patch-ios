import PatchCore
import SwiftUI

/// The app's shell.
///
/// A tab bar rather than a button on Today pushing a second screen: Today and
/// Statistics are peers, both are places you return to, and neither is a
/// detail of the other. It also leaves the calendar somewhere obvious to go.
struct RootView: View {
    let store: GoalStore

    /// Per-install, not per-goal-list: someone who deliberately archives
    /// everything should land on an empty Today screen, not be sent back
    /// through onboarding as though the app were new.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        tabs
            .id(hasCompletedOnboarding)
            .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
                OnboardingView(model: OnboardingModel(store: store)) {
                    hasCompletedOnboarding = true
                }
                // No swipe-to-dismiss: leaving halfway would drop the user
                // into an empty app with no way back to the templates.
                .interactiveDismissDisabled()
            }
            .task {
                // An install that already has goals predates onboarding, or
                // reached Today some other way. Don't show it the welcome.
                if !hasCompletedOnboarding, let goals = try? store.loadGoals(), !goals.isEmpty {
                    hasCompletedOnboarding = true
                }
            }
    }

    private var tabs: some View {
        // Rebuilt when onboarding finishes, so Today picks up the goals it was
        // created with. Today loads once on appear, and it appears behind the
        // cover — before there is anything to load.
        TabView {
            Tab("Today", systemImage: "checkmark.circle") {
                ContentView(model: TodayModel(store: store))
            }

            Tab("Calendar", systemImage: "calendar") {
                CalendarScreen(model: CalendarModel(store: store))
            }

            Tab("Statistics", systemImage: "chart.bar") {
                StatisticsView(model: StatisticsModel(store: store))
            }
        }
    }
}
