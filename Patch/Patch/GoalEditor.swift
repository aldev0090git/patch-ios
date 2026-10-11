import PatchCore
import SwiftUI

/// Creates a goal, or edits an existing one.
///
/// A plain `Form`. A goal has a name, a number, a unit and a schedule, and
/// every iOS user already knows how to fill in a form — a custom layout here
/// would be novelty at the cost of familiarity.
struct GoalEditor: View {
    @Environment(\.dismiss) private var dismiss

    private let existing: Goal?
    private let onSave: (Goal) -> Void

    @State private var title: String
    @State private var remindsMe: Bool
    @State private var notificationsDenied = false
    @State private var reminderTime: Date
    @State private var symbolName: String
    @State private var kind: MeasureKind
    @State private var target: Decimal
    @State private var direction: Direction
    @State private var repeatsDaily: Bool
    @State private var weekdays: Set<Weekday>

    /// A short, deliberately curated list. A full symbol browser is thousands
    /// of icons deep and makes a two-second decision feel like a chore.
    private static let symbols = [
        "book", "pencil", "graduationcap", "brain.head.profile",
        "figure.walk", "figure.run", "dumbbell", "figure.strengthtraining.functional",
        "drop", "cup.and.saucer", "fork.knife", "pills",
        "bed.double", "moon.stars", "sun.max", "leaf",
        "heart", "banknote", "nosign", "music.note"
    ]

    init(goal: Goal?, onSave: @escaping (Goal) -> Void) {
        existing = goal
        self.onSave = onSave

        let measure = goal?.measure ?? .minutes(20)
        // Shows the resolved name, so a seeded goal is editable in the
        // language the user is actually reading.
        _title = State(initialValue: goal?.localizedTitle ?? "")
        _symbolName = State(initialValue: goal?.symbolName ?? "book")
        _kind = State(initialValue: measure.kind)
        _target = State(
            initialValue: MeasureInput.fromCanonical(measure.dailyTarget, kind: measure.kind)
        )
        _direction = State(initialValue: goal?.direction ?? .atLeast)
        _remindsMe = State(initialValue: goal?.reminder != nil)
        // Defaults to a time someone is likely awake and not yet asleep, rather
        // than to whenever the editor happened to be opened.
        _reminderTime = State(initialValue: Self.time(from: goal?.reminder) ?? Self.defaultTime)

        switch goal?.schedule ?? .daily {
        case .daily:
            _repeatsDaily = State(initialValue: true)
            _weekdays = State(initialValue: Set(Weekday.allCases))
        case .daysOfWeek(let days):
            _repeatsDaily = State(initialValue: false)
            _weekdays = State(initialValue: days)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $title)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Icon") {
                    symbolPicker
                }

                Section("Target") {
                    Picker("Measure", selection: $kind) {
                        ForEach(MeasureKind.allCases, id: \.self) { kind in
                            Text(MeasureInput.kindLabel(for: kind)).tag(kind)
                        }
                    }

                    HStack {
                        TextField("Amount", value: $target, format: .number)
                            .keyboardType(.decimalPad)
                        Text(MeasureInput.unitLabel(for: kind))
                            .foregroundStyle(.secondary)
                    }

                    Picker("Aim to", selection: $direction) {
                        Text("Reach the target").tag(Direction.atLeast)
                        Text("Stay under it").tag(Direction.atMost)
                    }
                }

                Section("Reminder") {
                    Toggle("Remind me", isOn: $remindsMe)
                    if remindsMe, notificationsDenied {
                        // iOS only ever shows its prompt once, so asking again
                        // does nothing. Say where the switch actually is.
                        Label {
                            Text("Notifications are off for Patch. Turn them on in Settings.")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        .font(.caption)
                    }
                    if remindsMe {
                        DatePicker(
                            "Time",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        // Says what will actually happen: the reminder follows
                        // the goal's own days, so a Mon/Wed goal is silent on
                        // Sunday and the user should not have to guess that.
                        Text(reminderExplanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Repeat") {
                    Picker("Days", selection: $repeatsDaily) {
                        Text("Every day").tag(true)
                        Text("Certain days").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if !repeatsDaily {
                        weekdayPicker
                    }
                }
            }
            .onChange(of: remindsMe) { _, isOn in
                guard isOn else { notificationsDenied = false; return }
                Task { notificationsDenied = await !NotificationScheduler().requestAuthorization() }
            }
            .navigationTitle(existing == nil ? Text("New Goal") : Text("Edit Goal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(makeGoal())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    private static let defaultTime: Date = {
        Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? .now
    }()

    private static func time(from reminder: Reminder?) -> Date? {
        guard let reminder else { return nil }
        return Calendar.current.date(
            from: DateComponents(hour: reminder.hour, minute: reminder.minute)
        )
    }

    private var reminderExplanation: String {
        repeatsDaily
            ? String(localized: "Every day at this time.")
            : String(localized: "Only on the days you picked below.")
    }

    private var chosenReminder: Reminder? {
        guard remindsMe else { return nil }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        guard let hour = parts.hour, let minute = parts.minute else { return nil }
        return Reminder(hour: hour, minute: minute)
    }

    private var symbolPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
            ForEach(Self.symbols, id: \.self) { symbol in
                Button {
                    symbolName = symbol
                } label: {
                    Image(systemName: symbol)
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                        .background(
                            symbol == symbolName ? Color.accentColor.opacity(0.2) : Color.clear,
                            in: .circle
                        )
                        .foregroundStyle(symbol == symbolName ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: symbol))
                .accessibilityAddTraits(symbol == symbolName ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 4)
    }

    /// Ordered by the user's own first day of the week, not hardcoded to Monday.
    private var weekdayPicker: some View {
        let calendar = Calendar.current
        let ordered = (0..<7).compactMap { offset in
            Weekday(rawValue: (calendar.firstWeekday - 1 + offset) % 7 + 1)
        }

        return HStack(spacing: 6) {
            ForEach(ordered, id: \.self) { day in
                let isOn = weekdays.contains(day)
                Button {
                    if isOn {
                        weekdays.remove(day)
                    } else {
                        weekdays.insert(day)
                    }
                } label: {
                    Text(verbatim: calendar.veryShortWeekdaySymbols[day.rawValue - 1])
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            isOn ? Color.accentColor.opacity(0.2) : Color(uiColor: .tertiarySystemFill),
                            in: .capsule
                        )
                        .foregroundStyle(isOn ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 4)
    }

    /// A goal needs a name, somewhere to get to, and at least one day to do it
    /// on. A zero target is allowed only when the point is to stay at zero.
    private var isValid: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard repeatsDaily || !weekdays.isEmpty else { return false }
        return direction == .atMost || target > 0
    }

    private func makeGoal() -> Goal {
        let name = Goal.titleToSave(typed: title, editing: existing)
        let newTarget = MeasureInput.toCanonical(target, kind: kind)
        let built = Goal(
            id: existing?.id ?? UUID(),
            title: name.title,
            titleKey: name.key,
            symbolName: symbolName,
            measure: Measure(kind: kind, dailyTarget: existing?.measure.dailyTarget ?? newTarget),
            direction: direction,
            schedule: repeatsDaily ? .daily : .daysOfWeek(weekdays),
            cumulativeTarget: existing?.cumulativeTarget,
            // Keeping the original creation date matters: statistics and streaks
            // both refuse to look back before it, so resetting it on every edit
            // would quietly erase the goal's history.
            createdAt: existing?.createdAt ?? .now,
            targetHistory: existing?.targetHistory ?? [],
            reminder: chosenReminder,
            archivedAt: existing?.archivedAt
        )

        // Recorded as a change rather than written straight in, so the days
        // already logged keep being judged against what they were asked for.
        // A brand new goal has nothing to preserve, and changing the kind
        // changes the unit, which makes the old numbers meaningless anyway.
        guard existing != nil, kind == existing?.measure.kind else {
            var fresh = built
            fresh.measure = Measure(kind: kind, dailyTarget: newTarget)
            fresh.targetHistory = []
            return fresh
        }
        return built.withTarget(newTarget)
    }
}

#Preview("New") {
    GoalEditor(goal: nil) { _ in }
}

#Preview("Editing") {
    GoalEditor(goal: GoalTemplateCatalog.gym.makeGoal(title: "Gym")) { _ in }
}
