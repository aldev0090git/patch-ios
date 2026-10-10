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
                            onUndo: { undoLast(for: goal) }
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

    /// Removes the most recent entry logged today for this goal.
    ///
    /// A mistap is not history worth keeping, so it is deleted outright rather
    /// than offset by a negative entry. Negative entries remain the right tool
    /// for correcting a day you genuinely over-reported.
    private func undoLast(for goal: Goal) {
        let calendar = Calendar.current
        guard let index = entries.lastIndex(where: {
            $0.goalID == goal.id && calendar.isDateInToday($0.loggedAt)
        }) else { return }
        entries.remove(at: index)
    }
}

private struct GoalRow: View {
    let goal: Goal
    let progress: DayProgress
    let loggedToday: Int
    let onLog: (Decimal) -> Void
    let onUndo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ProgressRing(fraction: progress.fraction, symbolName: goal.symbolName)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if progress.isAchieved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            HStack(spacing: 8) {
                ForEach(QuickAddSuggestions.options(for: goal.measure)) { option in
                    Button(MeasureFormatter.short(option.amount, kind: goal.measure.kind)) {
                        withAnimation(.snappy) { onLog(option.amount) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if loggedToday > 0 {
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.snappy) { onUndo() }
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.secondary)
                    .accessibilityLabel("Undo last entry for \(goal.title)")
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.vertical, 6)
        .animation(.snappy, value: progress.total)
    }

    private var subtitle: String {
        let kind = goal.measure.kind
        if goal.direction == .atMost {
            return progress.isAchieved ? "Clean today" : "Over the limit"
        }
        let done = MeasureFormatter.short(progress.total, kind: kind)
        let target = MeasureFormatter.short(progress.target, kind: kind)
        return "\(done) of \(target)"
    }
}

private struct ProgressRing: View {
    let fraction: Double
    let symbolName: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbolName)
                .font(.system(size: 15))
                .foregroundStyle(.tint)
        }
        .frame(width: 42, height: 42)
        .animation(.snappy, value: fraction)
    }
}

#Preview {
    ContentView()
}
