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

    /// Read here and applied once, at the top. Every screen — and every sheet
    /// presented from one — inherits both, so no view has to remember to ask
    /// what the theme is.
    @AppStorage(SettingsKey.appearance) private var appearance = Appearance.system
    @AppStorage(SettingsKey.accent) private var accent = AccentTheme.blue

    @AppStorage(SettingsKey.remindersEnabled) private var remindersEnabled = false
    @AppStorage(SettingsKey.reminderTimes) private var reminderTimesRaw
        = DailyCheckIns.text(DailyCheckIns.standard)

    var body: some View {
        shell
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

                // Re-stated on every launch rather than only when the setting
                // changes. Permission can be revoked in iOS Settings, and a
                // restored backup brings the preference without the requests.
                await NotificationScheduler().sync(
                    times: DailyCheckIns.parse(reminderTimesRaw),
                    isEnabled: remindersEnabled
                )
            }
            // Outside the presentation modifiers, not inside: a sheet inherits
            // the environment of the view the modifier is attached to, so a
            // tint applied further in would stop at the onboarding cover and
            // leave the first screen of the app the only unthemed one.
            //
            // `.tint` covers controls; `themeAccent` covers the places that
            // need the colour as a value rather than as a style.
            // `Color.accentColor` is not a third option — it reads the asset
            // catalog and ignores `.tint` entirely.
            .tint(accent.color)
            .environment(\.themeAccent, accent.color)
            .preferredColorScheme(appearance.colorScheme)
    }

    private var shell: some View {
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
