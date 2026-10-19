import PatchCore
import SwiftUI

struct ContentView: View {
    @Environment(\.themeAccent) private var themeAccent
    @State var model: TodayModel
    @State private var editing: Editing?
    @State private var isShowingSettings = false

    /// What the editor sheet is currently doing. One piece of state rather
    /// than a bool plus an optional goal, which can disagree with each other.
    private enum Editing: Identifiable {
        case new
        case existing(Goal)

        var id: String {
            switch self {
            case .new: "new"
            case .existing(let goal): goal.id.uuidString
            }
        }

        var goal: Goal? {
            switch self {
            case .new: nil
            case .existing(let goal): goal
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.todaysGoals) { goal in
                    let hasLogged = model.hasLoggedToday(goal)

                    GoalCard(
                        goal: goal,
                        progress: model.progress(for: goal),
                        streak: model.streak(for: goal)
                    ) { amount in
                        log(amount, for: goal)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    // Reset is hidden behind a swipe rather than sitting on the
                    // card. It is destructive and rarely wanted, and a button
                    // that throws away the day does not belong next to the
                    // buttons that build it up.
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Archive", role: .destructive) {
                            archive(goal)
                        }
                        if hasLogged {
                            // No delay and no animation wrapper: the card is
                            // the same height either way, so there is nothing
                            // for the closing swipe row to collide with.
                            Button("Reset") { reset(goal) }
                                .tint(.orange)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button("Edit") { editing = .existing(goal) }
                            .tint(themeAccent)
                    }
                    // The same two actions by long press, because a swipe is
                    // not discoverable on its own.
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") {
                            editing = .existing(goal)
                        }
                        // Also here, not only behind the swipe. A gesture
                        // nobody finds may as well not exist, and this is the
                        // only way to undo a mistaken tap.
                        if hasLogged {
                            Button("Reset", systemImage: "arrow.uturn.backward") {
                                reset(goal)
                            }
                        }
                        Button("Archive", systemImage: "archivebox", role: .destructive) {
                            archive(goal)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Today")
            // Inline, because the progress header below is the hero of this
            // screen. A large title competes with it for the same space and
            // loses, leaving the screen looking untitled.
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                TodayProgressHeader(progress: model.todaysProgress)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                        .labelStyle(.iconOnly)
                        // Identified as well as labelled: the label is
                        // localised, so a test that names it only works in
                        // the language it was written in.
                        .accessibilityIdentifier("today.settings")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add goal", systemImage: "plus") { editing = .new }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("today.add")
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .sheet(item: $editing) { editing in
                GoalEditor(goal: editing.goal) { goal in
                    withAnimation(.snappy) { model.save(goal) }
                }
            }
            // On every appearance, not once. A tab keeps its view alive, so
            // a goal logged on another one stayed invisible here until the
            // app was relaunched — and backdating makes that obvious.
            .onAppear { model.load() }
            // One place for the bad news, so no caller has to remember to
            // report its own failure.
            .onChange(of: model.failure) { _, failure in
                if failure != nil { Haptics.play(.failure) }
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { model.failure != nil },
                    set: { if !$0 { model.failure = nil } }
                )
            ) {
                Button("OK", role: .cancel) { model.failure = nil }
            } message: {
                Text(model.failure ?? "")
            }
        }
    }

    /// Logs an amount, then says in the hand what that amount did.
    ///
    /// The event is picked by comparing the day *before* and *after* the entry
    /// lands, because "you finished something" is a transition and not a
    /// property of the number. The identical call is a light tap on the way to
    /// twenty push-ups and a success note on the one that reaches twenty.
    private func log(_ amount: Decimal, for goal: Goal) {
        let wasAchieved = model.progress(for: goal).isAchieved
        let dayWasComplete = model.isDayComplete

        model.log(amount, for: goal)

        // A write that failed is not something to congratulate; the alert and
        // its own haptic are already on their way.
        guard model.failure == nil else { return }

        if model.isDayComplete, !dayWasComplete {
            Haptics.play(.allDone)
        } else if model.progress(for: goal).isAchieved, !wasAchieved {
            Haptics.play(.completed)
        } else {
            Haptics.play(.logged)
        }
    }

    private func reset(_ goal: Goal) {
        model.resetToday(for: goal)
        if model.failure == nil { Haptics.play(.reset) }
    }

    private func archive(_ goal: Goal) {
        withAnimation(.snappy) { model.archive(goal) }
        if model.failure == nil { Haptics.play(.archived) }
    }
}

#Preview {
    // The in-memory store lives in PatchCore precisely so previews can use it
    // without the app depending on a test bundle.
    let goals = [
        GoalTemplateCatalog.read.makeGoal(title: "Read"),
        GoalTemplateCatalog.water.makeGoal(title: "Water"),
        GoalTemplateCatalog.quitSmoking.makeGoal(title: "Don't smoke")
    ]
    return ContentView(model: TodayModel(store: InMemoryGoalStore(goals: goals)))
}
