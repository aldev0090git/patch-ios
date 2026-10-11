import PatchCore
import SwiftUI

struct ContentView: View {
    @State var model: TodayModel
    @State private var editing: Editing?
    @State private var scheduler = NotificationScheduler()

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
                        model.log(amount, for: goal)
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
                            withAnimation(.snappy) { model.archive(goal) }
                            // An archived goal must stop reminding you about
                            // itself; nothing gets notifications switched off
                            // faster.
                            Task { await scheduler.sync(goals: model.goals) }
                        }
                        if hasLogged {
                            // No delay and no animation wrapper: the card is
                            // the same height either way, so there is nothing
                            // for the closing swipe row to collide with.
                            Button("Reset") { model.resetToday(for: goal) }
                                .tint(.orange)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button("Edit") { editing = .existing(goal) }
                            .tint(.accentColor)
                    }
                    // The same two actions by long press, because a swipe is
                    // not discoverable on its own.
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") {
                            editing = .existing(goal)
                        }
                        Button("Archive", systemImage: "archivebox", role: .destructive) {
                            withAnimation(.snappy) { model.archive(goal) }
                            Task { await scheduler.sync(goals: model.goals) }
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
                ToolbarItem(placement: .primaryAction) {
                    Button("Add goal", systemImage: "plus") { editing = .new }
                        .labelStyle(.iconOnly)
                }
            }
            .sheet(item: $editing) { editing in
                GoalEditor(goal: editing.goal) { goal in
                    withAnimation(.snappy) { model.save(goal) }
                    Task { await scheduler.sync(goals: model.goals) }
                }
            }
            .task {
                model.load()
                // Also on every appear: a goal can reach the store from
                // onboarding or a future sync without this screen being told.
                await scheduler.sync(goals: model.goals)
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

    /// Resets a goal once its swipe row has finished closing.
    ///
    /// Resetting brings the action buttons back, which makes the card taller.
    /// Doing that while the row is still sliding shut puts the card outside the
    /// row's current bounds, and a `List` does not clip its rows — so the card
    /// drew across the one above it and sat slightly off to the left.
    ///
    /// Waiting the length of the swipe animation separates the two into
    /// beats: the row closes, then the card visibly unwinds. That reads better
    /// than both at once even when it does not glitch.
    private func reset(_ goal: Goal) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { model.resetToday(for: goal) }
        }
    }
}

/// One goal, as a card.
///
/// Two separate signals, deliberately not duplicating each other: the ring
/// carries *how far along today is*, and the card's background carries *what
/// state the day is in* — plain while it is running, green once it is done.
/// Filling the background by fraction instead made a part-finished card look
/// split in two rather than partly filled.
private struct GoalCard: View {
    let goal: Goal
    let progress: DayProgress
    let streak: Int
    let onLog: (Decimal) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Scaled so the ring and the tick grow with the text rather than shrinking
    /// into a corner of it. A fixed 44pt circle beside accessibility-sized type
    /// looks like a rendering bug.
    @ScaledMetric(relativeTo: .headline) private var ringSize: CGFloat = 44
    @ScaledMetric(relativeTo: .title3) private var statusIconSize: CGFloat = 30

    @State private var isEnteringManually = false

    /// Equal columns, so controls line up across every card no matter how many
    /// a goal needs.
    ///
    /// Halved at accessibility text sizes. Four columns still fit there, but
    /// only by shrinking the labels below the size the user asked for, which
    /// defeats the point of asking. Two columns let the text render at full
    /// size and wrap to a second row instead.
    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 4
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    private var accent: Color {
        if progress.isAchieved { return .green }
        if progress.isFailed { return .orange }
        return .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Color(uiColor: .secondarySystemGroupedBackground)
                if progress.isAchieved || progress.isFailed {
                    accent.opacity(0.22)
                }
            }
            // Scoped to the background. Animating the whole card instead meant
            // its frame animated too, and while a swipe row was closing the two
            // fought: the card slid out of its own row and resized mid-flight.
            .animation(.easeOut(duration: 0.35), value: progress.isAchieved)
            .animation(.easeOut(duration: 0.35), value: progress.isFailed)
        }
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .sheet(isPresented: $isEnteringManually) {
            ManualEntrySheet(goal: goal) { amount in
                withAnimation(.snappy) { onLog(amount) }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ProgressRing(
                fraction: progress.isFailed ? 1 : progress.fraction,
                symbolName: goal.symbolName,
                accent: accent,
                size: ringSize
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: goal.localizedTitle)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // "Done today" and "Not yet" are different sentences, not
                    // one value changing. Cross-dissolving them draws both at
                    // once and neither is readable.
                    .animation(nil, value: subtitle)
            }

            Spacer(minLength: 8)

            statusIcon
                .animation(.snappy, value: progress.isAchieved)
                .animation(.snappy, value: progress.isFailed)
        }
    }

    /// Every settled state gets a mark. A card with no icon means "still in
    /// progress", so a failed day without one reads as empty and broken.
    @ViewBuilder
    private var statusIcon: some View {
        if progress.isAchieved {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: statusIconSize))
                .foregroundStyle(.white, .green)
                .transition(.scale.combined(with: .opacity))
        } else if progress.isFailed {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: statusIconSize))
                .foregroundStyle(.white, .orange)
                .transition(.scale.combined(with: .opacity))
        }
    }

    /// The bottom half of the card: buttons while there is work left, the
    /// streak once there is not.
    ///
    /// Both are always laid out, one of them invisible, so the card is exactly
    /// as tall when done as when not. That is not a styling choice — a card
    /// that changes height makes its `List` row animate its own height
    /// underneath SwiftUI, and because `List` does not clip rows the card drew
    /// across its neighbour every time a goal was reset. A constant height
    /// makes that impossible rather than merely unlikely, and it turns the
    /// change into a cross-fade in place with nothing moving.
    private var footer: some View {
        ZStack {
            actions
                .opacity(progress.isAchieved ? 0 : 1)
                .allowsHitTesting(!progress.isAchieved)
                .accessibilityHidden(progress.isAchieved)

            doneFooter
                .opacity(progress.isAchieved ? 1 : 0)
                .accessibilityHidden(!progress.isAchieved)
        }
        .animation(.easeInOut(duration: 0.3), value: progress.isAchieved)
    }

    /// What a finished goal says for itself. The streak is the reward for
    /// having done it; without one there is nothing to boast about yet.
    @ViewBuilder
    private var doneFooter: some View {
        if streak > 1 {
            Label {
                Text("\(streak) day streak")
            } icon: {
                Image(systemName: "flame.fill").foregroundStyle(.orange)
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("Done for today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actions: some View {
        Group {
            LazyVGrid(columns: columns, spacing: 8) {
                switch goal.loggingStyle {
                case .incremental:
                    ForEach(QuickAddSuggestions.options(for: goal.measure)) { option in
                        // Verbatim: MeasureFormatter has already produced this
                        // in the user's language, so it must not be looked up
                        // as a key.
                        actionButton(
                            Text(verbatim: MeasureFormatter.short(option.amount, kind: goal.measure.kind))
                        ) {
                            withAnimation(.snappy) { onLog(option.amount) }
                        }
                    }
                    actionButton(Text("Manual")) { isEnteringManually = true }

                case .single:
                    actionButton(Text("Done")) {
                        withAnimation(.snappy) { onLog(1) }
                    }
                }
            }
        }
    }

    /// Takes a `Text` rather than a `String` on purpose.
    ///
    /// A `String` parameter silently loses localisation: `Text("Manual")` is a
    /// localised key, but `Text(someString)` is not, so passing the literal
    /// through a `String` shipped "Manual" and "Done" in English to every
    /// language while the rest of the screen translated correctly. Asking for
    /// a `Text` forces each caller to say which it means.
    ///
    /// The expanding frame goes on the *label*, not the button. Putting it on
    /// the button only makes the invisible slots equal: the bordered background
    /// still hugs its text, so "5" renders as a tiny pill beside a wide
    /// "Manual".
    private func actionButton(_ label: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    /// Built with `String(localized:)` rather than returned as a plain string:
    /// `Text(someString)` does not localise, so a literal here would ship in
    /// English to every language.
    private var subtitle: String {
        let kind = goal.measure.kind
        if goal.loggingStyle == .single {
            return progress.isAchieved
                ? String(localized: "Done today")
                : String(localized: "Not yet")
        }
        if goal.direction == .atMost {
            return progress.isAchieved
                ? String(localized: "Within limit")
                : String(localized: "Over the limit")
        }
        let done = MeasureFormatter.short(progress.total, kind: kind)
        let target = MeasureFormatter.short(progress.target, kind: kind)
        return String(localized: "\(done) of \(target)")
    }
}

private struct ProgressRing: View {
    let fraction: Double
    let symbolName: String
    let accent: Color
    let size: CGFloat

    /// Keeps the stroke and glyph in proportion as the ring scales, so it reads
    /// the same at every text size instead of turning into a thin hoop.
    private var lineWidth: CGFloat { max(3, size * 0.09) }
    private var glyphSize: CGFloat { size * 0.36 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbolName)
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: size, height: size)
        // Must not overshoot. Any bounce sends the trim past its target, and
        // past zero means SwiftUI clamps the negative part and then settles
        // back up through a small positive — a stub of arc on a ring that is
        // supposed to be empty. `easeOut` sweeps without overshooting.
        .animation(.easeOut(duration: 0.4), value: fraction)
        .animation(.easeOut(duration: 0.3), value: accent)
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
