import PatchCore
import SwiftUI

struct ContentView: View {
    @State private var goals = SampleData.goals
    @State private var entries: [Entry] = []

    private let calculator = ProgressCalculator()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(todaysGoals) { goal in
                        GoalCard(
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
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
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

/// One goal, as a card whose background fills with its own progress.
///
/// Every card uses the same accent colour rather than one per goal. Five
/// different colours made the list read as five unrelated things and left the
/// eye nowhere to rest; one colour lets *state* carry the meaning instead —
/// blue is in progress, green is done, orange is a day gone wrong.
///
/// The fill is a tint over the normal card colour rather than a solid block of
/// saturated colour. Text keeps its standard colours, so it stays legible in
/// both appearances and under Increase Contrast — which a white-on-magenta
/// card cannot promise once someone raises their text size.
private struct GoalCard: View {
    let goal: Goal
    let progress: DayProgress
    let loggedToday: Int
    let onLog: (Decimal) -> Void
    let onReset: () -> Void

    @State private var isEnteringManually = false

    /// Four equal columns, so controls line up across every card no matter how
    /// many a goal needs.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    /// One accent for every goal, so colour means state rather than identity.
    private var tint: Color { .blue }

    private var fillColor: Color {
        if progress.isAchieved { return .green }
        if progress.isFailed { return .orange }
        return tint
    }

    /// A failed day fills completely: a part-filled card would read as partly
    /// successful.
    private var fillFraction: Double {
        progress.isFailed ? 1 : progress.fraction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            actions
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .leading) {
                Color(uiColor: .secondarySystemGroupedBackground)
                GeometryReader { proxy in
                    fillColor
                        .opacity(progress.isAchieved || progress.isFailed ? 0.3 : 0.22)
                        .frame(width: proxy.size.width * fillFraction)
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
            ZStack {
                Circle().fill(tint.opacity(0.2))
                Image(systemName: goal.symbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if loggedToday > 0 {
                Button("Reset") {
                    withAnimation(.snappy) { onReset() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                // Red: it throws away everything logged today, and nothing else
                // on the card is destructive.
                .tint(.red)
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

    /// The action row. A grid rather than a stack so a lone Done button is the
    /// same width as a "500 ml" button and sits in the same first column.
    @ViewBuilder
    private var actions: some View {
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
                // Collapses once done: the tick and Reset above already say so,
                // and a lone disabled button would just be noise.
                if loggedToday == 0 {
                    actionButton("Done") {
                        withAnimation(.snappy) { onLog(1) }
                    }
                }
            }
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
        .tint(tint)
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

#Preview {
    ContentView()
}
