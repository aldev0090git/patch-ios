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

    @State private var goals: [Goal] = []
    @State private var editing: Goal?
    @State private var failure: String?
    /// Held rather than deleted immediately: this is the one action in the
    /// app that cannot be undone, so it asks first.
    @State private var pendingDeletion: Goal?

    private var archived: [Goal] { goals.filter(\.isArchived) }
    private var ordered: [Goal] { goals.filter { !$0.isArchived } + archived }

    /// Active first, archived last.
    ///
    /// This was tried, abandoned and reinstated. Sinking a row to the bottom
    /// looked broken for three rounds — the list flickered, a goal elsewhere
    /// vanished for a frame, the footer jumped into the gap — and none of it
    /// was the sorting's fault. The causes were a `save` that reloaded the
    /// whole array so every row re-diffed, a footer that only existed once
    /// something was archived, and a swipe dismissing into the same frames.
    ///
    /// With those fixed the move is what it always should have been: one row
    /// changing place in one section, which is the same thing Today does
    /// when goals are dragged.

    var body: some View {
        List {
            if goals.isEmpty {
                ContentUnavailableView(
                    "No goals yet",
                    systemImage: "target",
                    description: Text("Goals you add will be listed here.")
                )
            }

            // **One section, deliberately.** Two — Active and Archived —
            // read better on paper and are broken in practice: archiving
            // moves the row across the gap between them, and `List` animates
            // that as a flight *through* the section header and footer, both
            // drawn on top of each other. Neither dropping `withAnimation`
            // nor a transaction with `disablesAnimations` stopped it.
            //
            // Within one section a row that changes place is an ordinary
            // reorder, which `List` has always handled cleanly — the same
            // move Today does when goals are dragged.
            Section {
                ForEach(ordered) { goal in
                    // Each row is its own card, the way Today's are.
                    //
                    // **No swipe actions.** They were tried on one edge and
                    // then both, and cost five rounds of visual problems: the
                    // row tearing out of its container, the list reflowing
                    // under a closing swipe, the text of the row below drawn
                    // through it. The long press carries Edit, Archive,
                    // Restore and Delete — which is where Today puts the same
                    // actions anyway, and the route that has worked
                    // throughout.
                    row(goal)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .contextMenu { menu(for: goal) }
                }
                // A row rather than a section footer. In a plain list a
                // footer draws its own opaque background and a hairline, so
                // it came out as a white strip across an otherwise grey page.
                //
                // Unconditional, either way: when it appeared only once
                // something was archived, archiving the first goal pushed the
                // layout mid-move and the text landed on top of a row.
                Text("Archived goals keep their history and stay out of Today. Restoring one brings it back.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 24, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        // No implicit animation on the list's contents. Archiving changes a
        // row's subtitle, its opacity and whether it has a chevron, and the
        // explanatory row below reflows while that animates — for a few
        // frames the text is drawn across the row above it. There is nothing
        // worth watching travel here, so nothing does.
        .animation(nil, value: goals)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.page)
        .navigationTitle("All Goals")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .sheet(item: $editing) { goal in
            GoalEditor(goal: goal) { edited in
                save(edited)
            }
        }
        // An **alert**, not a `confirmationDialog`. From a context menu the
        // dialog renders as a popover anchored to the row, and a popover
        // drops the cancel button on the grounds that tapping outside
        // dismisses it — so the only button on screen was the destructive
        // one. For the single irreversible action in the app, "Delete" alone
        // with no visible way out is the wrong thing to show.
        .alert(
            Text("Delete this goal?"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { goal in
            Button("Delete", role: .destructive) { delete(goal) }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { goal in
            // Names the goal and says what else goes, because "are you sure"
            // on its own tells nobody what they are about to lose.
            Text("\(goal.localizedTitle) and everything logged against it will be deleted. This can't be undone.")
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

    @ViewBuilder
    private func menu(for goal: Goal) -> some View {
        if goal.isArchived {
            // No Edit. An archived goal is not running, so changing its
            // target or schedule would apply to nothing — restore it first
            // and the usual editor is right there.
            Button("Restore", systemImage: "arrow.uturn.backward") { restore(goal) }
            // Only once archived. A goal made by mistake can be thrown away,
            // but never in one gesture from the list you use every day —
            // archiving first is the guard, and it is also how you find out
            // whether you actually wanted it gone.
            Button(role: .destructive) {
                pendingDeletion = goal
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        } else {
            Button("Edit", systemImage: "pencil") { editing = goal }
            // `.tint(.red)` because the root tint reaches inside a context
            // menu and claims the icon — see the note in `CLAUDE.md`.
            Button(role: .destructive) {
                archive(goal)
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(.red)
        }
    }

    private func row(_ goal: Goal) -> some View {
        Button {
            guard !goal.isArchived else { return }
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
                    (goal.isArchived
                        ? Text("Archived")
                        : Text(verbatim: ScheduleSummary.text(for: goal.schedule)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if !goal.isArchived {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            // Inside the label, not outside the button. Applied to the
            // `Button` these made a card that looked tappable everywhere and
            // only responded on the icon, the text and the chevron — the
            // padding between them was never part of the button.
            // `contentShape` then claims the whole rectangle, including the
            // gap the `Spacer` leaves in the middle.
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: .rect(cornerRadius: 16)
            )
            .contentShape(.rect(cornerRadius: 16))
        }
        .opacity(goal.isArchived ? 0.55 : 1)
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
    ///
    /// A restored goal goes to the **top**, the mirror of archiving sending
    /// one to the bottom. That is a real change to the arranged order, not a
    /// trick of this screen: it will be first on Today as well. Which is the
    /// point — a goal you have just brought back is one you mean to do, and
    /// burying it wherever it used to sit would hide the thing you just
    /// asked for. Dragging it elsewhere afterwards costs one gesture.
    private func restore(_ goal: Goal) {
        var changed = goal
        changed.archivedAt = nil
        changed.sortIndex = (goals.map(\.sortIndex).min() ?? 0) - 1
        save(changed)
    }

    /// The only irreversible thing in the app. Archiving keeps the history
    /// and can be undone; this does not.
    private func delete(_ goal: Goal) {
        do {
            try store.deleteGoal(id: goal.id)
            goals.removeAll { $0.id == goal.id }
            pendingDeletion = nil
            Haptics.play(.archived)
        } catch {
            failure = String(localized: "Couldn't delete that. \(error.localizedDescription)")
        }
    }

    private func save(_ goal: Goal) {
        do {
            try store.save(goal)
            // **One element, not the whole array.** Reloading everything made
            // SwiftUI re-diff every row, and rows unrelated to the change
            // flickered out and back while the list settled — a goal three
            // places down would vanish for a frame and the footer would jump
            // up into the gap. Replacing the single goal updates one row and
            // leaves the rest untouched.
            if let index = goals.firstIndex(where: { $0.id == goal.id }) {
                goals[index] = goal
            } else {
                load()
            }
            Haptics.play(.selection)
        } catch {
            failure = String(localized: "Couldn't save that. \(error.localizedDescription)")
        }
    }
}
