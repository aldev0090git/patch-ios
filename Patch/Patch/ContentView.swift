import PatchCore
import SwiftUI

struct ContentView: View {
    @State private var goals = SampleData.goals
    @State private var entries: [Entry] = []

    private let calculator = ProgressCalculator()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(todaysGoals) { goal in
                        GoalRow(
                            goal: goal,
                            progress: calculator.progress(for: goal, entries: entries, on: .now),
                            loggedToday: loggedToday(for: goal),
                            onLog: { amount in
                                entries.append(Entry(goalID: goal.id, amount: amount))
                            },
                            onReset: { resetToday(for: goal) }
                        )
                    }
                }
            }
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

private struct GoalRow: View {
    let goal: Goal
    let progress: DayProgress
    let loggedToday: Int
    let onLog: (Decimal) -> Void
    let onReset: () -> Void

    @State private var isEnteringManually = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            actions
        }
        .padding(.vertical, 6)
        .animation(.snappy, value: progress.total)
        .sheet(isPresented: $isEnteringManually) {
            ManualEntrySheet(goal: goal, remaining: progress.remaining) { amount in
                withAnimation(.snappy) { onLog(amount) }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ProgressRing(
                fraction: progress.isFailed ? 1 : progress.fraction,
                symbolName: goal.symbolName,
                tint: progress.isFailed ? AnyShapeStyle(.orange) : AnyShapeStyle(.tint)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Reset sits up here rather than in the button row, so that row
            // stays exactly four equal slots at every state.
            if loggedToday > 0 {
                Button("Reset") {
                    withAnimation(.snappy) { onReset() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.secondary)
                .accessibilityLabel("Reset today's progress for \(goal.title)")
                .transition(.scale.combined(with: .opacity))
            }

            statusIcon
        }
    }

    /// Every settled state gets a mark. A row with no icon means "still in
    /// progress", so a failed day without one reads as an empty, broken row.
    @ViewBuilder
    private var statusIcon: some View {
        if progress.isAchieved {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
                .transition(.scale.combined(with: .opacity))
        } else if progress.isFailed {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
                .transition(.scale.combined(with: .opacity))
        }
    }

    /// The action row, which differs by how the goal is logged.
    ///
    /// Buttons share the row equally so that every goal's controls line up
    /// down the screen instead of each row wrapping to its own rhythm.
    @ViewBuilder
    private var actions: some View {
        switch goal.loggingStyle {
        case .incremental:
            HStack(spacing: 8) {
                ForEach(QuickAddSuggestions.options(for: goal.measure)) { option in
                    actionButton(MeasureFormatter.short(option.amount, kind: goal.measure.kind)) {
                        withAnimation(.snappy) { onLog(option.amount) }
                    }
                }

                actionButton("Manual") { isEnteringManually = true }
            }

        case .single:
            // Collapses once done: the tick and Reset above already say so,
            // and a lone disabled button would just be noise.
            if loggedToday == 0 {
                actionButton("Done") {
                    withAnimation(.snappy) { onLog(1) }
                }
            }
        }
    }

    /// The expanding frame goes on the *label*, not the button.
    ///
    /// Putting it on the button only makes the invisible slots equal: the
    /// bordered background still hugs its text, so "5" renders as a tiny pill
    /// beside a wide "Manual". Expanding the label makes the capsules
    /// themselves match, which is what lines the rows up down the screen.
    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
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
    var tint: AnyShapeStyle = AnyShapeStyle(.tint)

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbolName)
                .font(.system(size: 15))
                .foregroundStyle(tint)
        }
        .frame(width: 42, height: 42)
        .animation(.snappy, value: fraction)
    }
}

#Preview {
    ContentView()
}
