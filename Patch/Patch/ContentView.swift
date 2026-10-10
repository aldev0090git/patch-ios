import PatchCore
import SwiftUI

struct ContentView: View {
    @State private var goals = SampleData.goals
    @State private var entries: [Entry] = []

    private let calculator = ProgressCalculator()

    var body: some View {
        NavigationStack {
            List {
                ForEach(todaysGoals) { goal in
                    let loggedToday = loggedToday(for: goal)

                    GoalCard(
                        goal: goal,
                        progress: calculator.progress(for: goal, entries: entries, on: .now)
                    ) { amount in
                        entries.append(Entry(goalID: goal.id, amount: amount))
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    // Reset is hidden behind a swipe rather than sitting on the
                    // card. It is destructive and rarely wanted, and a button
                    // that throws away the day does not belong next to the
                    // buttons that build it up.
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if loggedToday > 0 {
                            Button("Reset", role: .destructive) {
                                withAnimation(.snappy) { resetToday(for: goal) }
                            }
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
                TodayProgressHeader(progress: todaysProgress)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .background(.bar)
            }
        }
    }

    private var todaysGoals: [Goal] {
        goals.filter { !$0.isArchived && $0.schedule.isScheduled(on: .now) }
    }

    private var todaysProgress: [DayProgress] {
        todaysGoals.map { calculator.progress(for: $0, entries: entries, on: .now) }
    }

    private func loggedToday(for goal: Goal) -> Int {
        entries.count { $0.goalID == goal.id && Calendar.current.isDateInToday($0.loggedAt) }
    }

    /// Resets everything logged today for this goal.
    ///
    /// Deletes rather than offsetting with a negative entry: a day you are
    /// resetting was mislogged, and that is not history worth keeping.
    /// Negative entries remain the right tool for correcting a past day that
    /// was genuinely over-reported.
    private func resetToday(for goal: Goal) {
        let calendar = Calendar.current
        entries.removeAll {
            $0.goalID == goal.id && calendar.isDateInToday($0.loggedAt)
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
    let onLog: (Decimal) -> Void

    @State private var isEnteringManually = false

    /// Four equal columns, so controls line up across every card no matter how
    /// many a goal needs.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    private var accent: Color {
        if progress.isAchieved { return .green }
        if progress.isFailed { return .orange }
        return .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            actions
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
        }
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .animation(.snappy, value: progress.total)
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
                accent: accent
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            statusIcon
        }
    }

    /// Every settled state gets a mark. A card with no icon means "still in
    /// progress", so a failed day without one reads as empty and broken.
    @ViewBuilder
    private var statusIcon: some View {
        if progress.isAchieved {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white, .green)
                .transition(.scale.combined(with: .opacity))
        } else if progress.isFailed {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white, .orange)
                .transition(.scale.combined(with: .opacity))
        }
    }

    /// The action row, hidden once the goal is done — there is nothing left to
    /// add, and the tick says so more clearly than four idle buttons.
    @ViewBuilder
    private var actions: some View {
        if !progress.isAchieved {
            LazyVGrid(columns: columns, spacing: 8) {
                switch goal.loggingStyle {
                case .incremental:
                    ForEach(QuickAddSuggestions.options(for: goal.measure)) { option in
                        actionButton(MeasureFormatter.short(option.amount, kind: goal.measure.kind)) {
                            withAnimation(.snappy) { onLog(option.amount) }
                        }
                    }
                    actionButton("Manual") { isEnteringManually = true }

                case .single:
                    actionButton("Done") {
                        withAnimation(.snappy) { onLog(1) }
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// The expanding frame goes on the *label*, not the button.
    ///
    /// Putting it on the button only makes the invisible slots equal: the
    /// bordered background still hugs its text, so "5" renders as a tiny pill
    /// beside a wide "Manual".
    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var subtitle: String {
        let kind = goal.measure.kind
        if goal.loggingStyle == .single {
            return progress.isAchieved ? "Done today" : "Not yet"
        }
        if goal.direction == .atMost {
            return progress.isAchieved ? "Within limit" : "Over the limit"
        }
        let done = MeasureFormatter.short(progress.total, kind: kind)
        let target = MeasureFormatter.short(progress.target, kind: kind)
        return "\(done) of \(target)"
    }
}

private struct ProgressRing: View {
    let fraction: Double
    let symbolName: String
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: 44, height: 44)
        .animation(.snappy, value: fraction)
    }
}

#Preview {
    ContentView()
}
