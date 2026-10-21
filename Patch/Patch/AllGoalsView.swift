import PatchCore
import SwiftUI

/// Every goal, including the ones today has no use for.
///
/// Today shows what is scheduled for today, which is right for Today and
/// leaves a hole: a goal set to Tuesdays and Thursdays is, on a Wednesday,
/// completely unreachable. Not visible, not editable, not archivable — the
/// only way to get it back was to wait for Tuesday. Archived goals had the
/// same problem permanently: archiving was a one-way door.
///
/// So this is the list that is always complete, and the only screen where a
/// goal can be brought back.
struct AllGoalsView: View {
    let store: GoalStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var goals: [Goal] = []
    @State private var editing: Goal?
    @State private var failure: String?

    private var active: [Goal] { goals.filter { !$0.isArchived } }
    private var archived: [Goal] { goals.filter(\.isArchived) }

    var body: some View {
        List {
            if goals.isEmpty {
                ContentUnavailableView(
                    "No goals yet",
                    systemImage: "target",
                    description: Text("Goals you add will be listed here.")
                )
            }

            if !active.isEmpty {
                Section(header: Text("Active")) {
                    ForEach(active) { goal in
                        row(goal)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Archive", role: .destructive) { archive(goal) }
                            }
                    }
                }
            }

            if !archived.isEmpty {
                Section {
                    ForEach(archived) { goal in
                        row(goal)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Restore") { restore(goal) }
                                    .tint(.green)
                            }
                    }
                } header: {
                    Text("Archived")
                } footer: {
                    Text("Archived goals keep their history and stay out of Today. Restoring one brings it back.")
                }
            }
        }
        .navigationTitle("All Goals")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .sheet(item: $editing) { goal in
            GoalEditor(goal: goal) { edited in
                save(edited)
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button("OK", role: .cancel) { failure = nil }
        } message: {
            Text(verbatim: failure ?? "")
        }
    }

    private func row(_ goal: Goal) -> some View {
        Button {
            editing = goal
        } label: {
            HStack(spacing: 12) {
                Image(systemName: goal.symbolName)
                    .font(.body)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: goal.localizedTitle)
                        .foregroundStyle(.primary)
                    Text(verbatim: ScheduleSummary.text(for: goal.schedule))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        // Without this the button tints its whole label, so the goal's name
        // and its schedule both come out accent-coloured and the row reads
        // as one long link rather than a title with a subtitle.
        .buttonStyle(.plain)
        .accessibilityIdentifier("allGoals.\(goal.id.uuidString)")
    }

    // MARK: - Writing

    private func load() {
        do {
            goals = GoalOrder.sorted(try store.loadGoals())
        } catch {
            failure = String(localized: "Couldn't load your goals. \(error.localizedDescription)")
        }
    }

    private func archive(_ goal: Goal) {
        var changed = goal
        changed.archivedAt = .now
        save(changed)
    }

    /// Archiving was a one-way door before this existed. Clearing the date
    /// is all it takes — the goal's entries were never deleted.
    private func restore(_ goal: Goal) {
        var changed = goal
        changed.archivedAt = nil
        save(changed)
    }

    private func save(_ goal: Goal) {
        do {
            try store.save(goal)
            withAnimation(Motion.animation(.snappy, reduceMotion: reduceMotion)) { load() }
            Haptics.play(.selection)
        } catch {
            failure = String(localized: "Couldn't save that. \(error.localizedDescription)")
        }
    }
}
