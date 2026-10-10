import PatchCore
import SwiftUI

struct ContentView: View {
    @State private var goals = SampleData.goals
    @State private var entries: [Entry] = []

    private let calculator = ProgressCalculator()
    private let statistics = StatisticsCalculator()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(todaysGoals) { goal in
                        GoalRow(
                            goal: goal,
                            progress: calculator.progress(for: goal, entries: entries, on: .now)
                        ) { amount in
                            entries.append(Entry(goalID: goal.id, amount: amount))
                        }
                    }
                } header: {
                    summaryHeader
                }
            }
            .navigationTitle("Today")
        }
    }

    private var todaysGoals: [Goal] {
        goals.filter { !$0.isArchived && $0.schedule.isScheduled(on: .now) }
    }

    private var summaryHeader: some View {
        let summary = statistics.summary(for: goals, entries: entries, on: .now)
        return Text("\(summary.completed) of \(summary.scheduled) done")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}

private struct GoalRow: View {
    let goal: Goal
    let progress: DayProgress
    let onLog: (Decimal) -> Void

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
