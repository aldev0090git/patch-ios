import PatchCore
import PatchStore
import SwiftData
import SwiftUI

@main
struct PatchApp: App {
    private let container = PatchApp.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView(store: demoAwareStore())
        }
        .modelContainer(container)
    }

    /// The real store, with a couple of months of plausible history when a
    /// screenshot run asks for it. `DemoData` is `#if DEBUG` only, so this
    /// collapses to the plain store in a release build.
    private func demoAwareStore() -> GoalStore {
        let store = SwiftDataGoalStore(context: container.mainContext)
        #if DEBUG
        if DemoData.isRequested { DemoData.install(into: store) }
        #endif
        return store
    }

    /// Falls back to an in-memory container rather than crashing.
    ///
    /// A store that cannot be opened — a failed migration, a corrupt file —
    /// should leave someone looking at an empty app they can still use, not a
    /// launch crash with no way back.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([StoredGoal.self, StoredEntry.self])

        if let container = try? ModelContainer(for: schema) {
            return container
        }

        let memoryOnly = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: schema, configurations: memoryOnly) {
            return container
        }

        fatalError("Could not create a model container, even in memory.")
    }
}
