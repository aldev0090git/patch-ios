import PatchCore
import SwiftUI

/// Creates a goal, or edits an existing one.
///
/// A plain `Form`. A goal has a name, a number, a unit and a schedule, and
/// every iOS user already knows how to fill in a form — a custom layout here
/// would be novelty at the cost of familiarity.
struct GoalEditor: View {
    @Environment(\.themeAccent) private var themeAccent
    @Environment(\.dismiss) private var dismiss

    private let existing: Goal?
    private let onSave: (Goal) -> Void

    @State private var title: String
    @State private var hasOverall: Bool
    @State private var overallTarget: Decimal
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var repeatMode: RepeatMode
    @State private var monthDays: Set<Int>

    /// Three states, so not a Bool. "Certain dates" is how a goal tied to a
    /// date rather than a rhythm is expressed — money put aside when the
    /// salary lands on the 1st, or on the 1st and the 15th.
    private enum RepeatMode: Hashable {
        case daily, certainWeekdays, certainDates
    }
    @State private var currencyCode: String
    @State private var symbolName: String
    @State private var kind: MeasureKind
    @State private var target: Decimal
    @State private var direction: Direction
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
        // The phone's own currency unless the goal already names one, so the
        // common case needs no decision at all.
        _hasOverall = State(initialValue: goal?.cumulativeTarget != nil)
        _overallTarget = State(
            initialValue: goal?.cumulativeTarget.map {
                MeasureInput.fromCanonical($0, kind: measure.kind)
            } ?? 0
        )
        _hasDeadline = State(initialValue: goal?.cumulativeDeadline != nil)
        _deadline = State(
            initialValue: goal?.cumulativeDeadline
                ?? Calendar.current.date(byAdding: .month, value: 6, to: .now)
                ?? .now
        )
        _currencyCode = State(
            initialValue: goal?.measure.currencyCode ?? CurrencyOptions.deviceDefault
        )
        switch goal?.schedule ?? .daily {
        case .daily:
            _repeatMode = State(initialValue: .daily)
            _weekdays = State(initialValue: Set(Weekday.allCases))
            _monthDays = State(initialValue: [])
        case .daysOfWeek(let days):
            _repeatMode = State(initialValue: .certainWeekdays)
            _weekdays = State(initialValue: days)
            _monthDays = State(initialValue: [])
        case .daysOfMonth(let dates):
            _repeatMode = State(initialValue: .certainDates)
            _weekdays = State(initialValue: Set(Weekday.allCases))
            _monthDays = State(initialValue: dates)
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
                        Text(verbatim: unitTrailing)
                            .foregroundStyle(.secondary)
                    }

                    if kind == .currency {
                        // Two sections rather than one long list: the four
                        // that cover almost every case, then the other
                        // hundred and sixty for the cases they do not.
                        Picker("Currency", selection: $currencyCode) {
                            Section("Common") {
                                ForEach(CurrencyOptions.featured, id: \.self) { code in
                                    Text(verbatim: CurrencyOptions.label(for: code)).tag(code)
                                }
                            }
                            Section("All currencies") {
                                ForEach(CurrencyOptions.others, id: \.self) { code in
                                    Text(verbatim: CurrencyOptions.label(for: code)).tag(code)
                                }
                            }
                        }
                    }

                    Picker("Aim to", selection: $direction) {
                        Text("Reach the target").tag(Direction.atLeast)
                        Text("Stay under it").tag(Direction.atMost)
                    }
                }

                Section("Overall goal") {
                    Toggle("Work toward a total", isOn: $hasOverall)
                    if hasOverall {
                        HStack {
                            TextField("Total", value: $overallTarget, format: .number)
                                .keyboardType(.decimalPad)
                            Text(verbatim: unitTrailing)
                                .foregroundStyle(.secondary)
                        }
                        Toggle("By a date", isOn: $hasDeadline)
                        if hasDeadline {
                            DatePicker(
                                "Date",
                                selection: $deadline,
                                in: Date.now...,
                                displayedComponents: .date
                            )
                        }
                    }
                }

                Section("Repeat") {
                    Picker("Days", selection: $repeatMode) {
                        Text("Every day").tag(RepeatMode.daily)
                        Text("Certain days").tag(RepeatMode.certainWeekdays)
                        Text("Certain dates").tag(RepeatMode.certainDates)
                    }
                    .pickerStyle(.segmented)

                    switch repeatMode {
                    case .daily:
                        EmptyView()
                    case .certainWeekdays:
                        WeekdayPicker(selection: $weekdays)
                    case .certainDates:
                        MonthDayPicker(selection: $monthDays)
                        // The 31st has to mean something in February, and
                        // guessing is worse than saying.
                        Text("A date the month doesn't have falls on its last day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(existing == nil ? Text("New Goal") : Text("Edit Goal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(makeGoal())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                    .accessibilityIdentifier("editor.save")
                }
            }
        }
    }

    /// The currency symbol replaces the generic unit label for money, so the
    /// field reads "120 €" rather than "120 money".
    private var unitTrailing: String {
        kind == .currency
            ? CurrencyOptions.symbol(for: currencyCode)
            : MeasureInput.unitLabel(for: kind)
    }

    /// Nil unless there is a real number behind it — an overall goal of zero
    /// is a toggle someone switched on and then left alone.
    private var chosenOverallTarget: Decimal? {
        guard hasOverall, overallTarget > 0 else { return nil }
        return MeasureInput.toCanonical(overallTarget, kind: kind)
    }

    private var chosenSchedule: Schedule {
        switch repeatMode {
        case .daily: .daily
        case .certainWeekdays: .daysOfWeek(weekdays)
        case .certainDates: .daysOfMonth(monthDays)
        }
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
                            symbol == symbolName ? themeAccent.opacity(0.2) : Color.clear,
                            in: .circle
                        )
                        .foregroundStyle(symbol == symbolName ? themeAccent : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: symbol))
                .accessibilityAddTraits(symbol == symbolName ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 4)
    }

    /// Ordered by the user's own first day of the week, not hardcoded to Monday.
    private var isValid: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch repeatMode {
        case .daily: break
        case .certainWeekdays: if weekdays.isEmpty { return false }
        case .certainDates: if monthDays.isEmpty { return false }
        }
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
            measure: Measure(
                kind: kind,
                dailyTarget: existing?.measure.dailyTarget ?? newTarget,
                currencyCode: currencyCode
            ),
            direction: direction,
            schedule: chosenSchedule,
            cumulativeTarget: chosenOverallTarget,
            cumulativeDeadline: chosenOverallTarget == nil || !hasDeadline ? nil : deadline,
            // Keeping the original creation date matters: statistics and streaks
            // both refuse to look back before it, so resetting it on every edit
            // would quietly erase the goal's history.
            createdAt: existing?.createdAt ?? .now,
            targetHistory: existing?.targetHistory ?? [],
            archivedAt: existing?.archivedAt
        )

        // Recorded as a change rather than written straight in, so the days
        // already logged keep being judged against what they were asked for.
        // A brand new goal has nothing to preserve, and changing the kind
        // changes the unit, which makes the old numbers meaningless anyway.
        guard existing != nil, kind == existing?.measure.kind else {
            var fresh = built
            fresh.measure = Measure(kind: kind, dailyTarget: newTarget, currencyCode: currencyCode)
            fresh.targetHistory = []
            return fresh
        }
        var updated = built.withTarget(newTarget)
        // Kept separately from the target: switching currency is a correction,
        // not a change of how much you are asking of yourself.
        updated.measure = Measure(
            kind: kind,
            dailyTarget: updated.measure.dailyTarget,
            currencyCode: currencyCode
        )
        return updated
    }
}

#Preview("New") {
    GoalEditor(goal: nil) { _ in }
}

#Preview("Editing") {
    GoalEditor(goal: GoalTemplateCatalog.gym.makeGoal(title: "Gym")) { _ in }
}
