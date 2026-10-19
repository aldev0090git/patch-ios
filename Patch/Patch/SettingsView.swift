import PatchCore
import SwiftUI

/// Look and feel, plus the one bit of help worth keeping reachable.
///
/// A sheet off the Today screen rather than a fourth tab: a tab bar is for
/// places you go back to, and this is a place you visit twice a year. Three
/// tabs also stay legible at accessibility text sizes where four do not.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(SettingsKey.appearance) private var appearance = Appearance.system
    @AppStorage(SettingsKey.accent) private var accent = AccentTheme.blue
    @AppStorage(SettingsKey.haptics) private var hapticsEnabled = true

    /// Off until asked for. Turning it on is what triggers iOS's permission
    /// prompt, and an app that asks on first launch, before it has shown what
    /// it is for, is the app people deny — after which there is no second
    /// chance, because iOS only ever prompts once.
    @AppStorage(SettingsKey.remindersEnabled) private var remindersEnabled = false
    @AppStorage(SettingsKey.reminderTimes) private var reminderTimesRaw
        = DailyCheckIns.text(DailyCheckIns.standard)

    @State private var isShowingHowItWorks = false
    @State private var notificationsDenied = false
    @State private var scheduler = NotificationScheduler()

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    // Words, not symbols: a segmented control shows one or
                    // the other, and a sun and a moon leave the third option
                    // with nothing obvious to wear.
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(verbatim: option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: appearance) { Haptics.play(.selection) }
                }

                Section {
                    accentPicker
                } header: {
                    Text("Accent")
                } footer: {
                    Text("Green means a day you finished, orange a day you missed — whichever accent you pick.")
                }

                Section {
                    Toggle("Vibration", isOn: $hapticsEnabled)
                        .onChange(of: hapticsEnabled) { _, isOn in
                            // Only on the way on, and only after the value is
                            // written: the point is to demonstrate what was
                            // just switched on. Buzzing as it goes off would
                            // be the app arguing with the user.
                            if isOn { Haptics.play(.completed) }
                        }
                } footer: {
                    Text("A short tap when you log something, and a longer one when you finish the day.")
                }

                reminders

                Section {
                    Button {
                        isShowingHowItWorks = true
                    } label: {
                        Label("How it works", systemImage: "hand.tap")
                    }
                } footer: {
                    Text("The gestures from the welcome screen, in case you tapped past them.")
                }

                Section {
                    LabeledContent("Version") {
                        Text(verbatim: Self.version)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isShowingHowItWorks) {
                HowItWorksSheet()
            }
            .task {
                // Only worth checking when reminders are meant to be on: the
                // warning is about a promise the app cannot keep, and it has
                // made no promise while the switch is off.
                guard remindersEnabled else { return }
                notificationsDenied = await !scheduler.isAuthorized
            }
            .onChange(of: remindersEnabled) { _, isOn in
                Task {
                    // Asked here, at the moment someone says they want
                    // reminders, rather than on first launch when they have
                    // nothing to say yes to.
                    if isOn {
                        notificationsDenied = await !scheduler.requestAuthorization()
                    } else {
                        notificationsDenied = false
                    }
                    await syncReminders()
                }
            }
            .onChange(of: reminderTimesRaw) { Task { await syncReminders() } }
        }
    }

    /// Swatches rather than a list of colour names: the thing being chosen is
    /// the colour itself, and a row reading "Teal" in default blue text shows
    /// you nothing about what you are about to get.
    private var accentPicker: some View {
        HStack(spacing: 12) {
            ForEach(AccentTheme.allCases) { option in
                Button {
                    accent = option
                    Haptics.play(.selection)
                } label: {
                    swatch(for: option)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: option.title))
                .accessibilityAddTraits(option == accent ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("accent.\(option.rawValue)")
            }
            Spacer(minLength: 0)
        }
        .animation(Motion.animation(.snappy(duration: 0.25), reduceMotion: reduceMotion),
                   value: accent)
    }

    /// Selection is shown by a ring around the swatch, not a tick inside it.
    /// A tick needs a colour that contrasts with whatever it sits on, and
    /// Graphite is near-black in light mode and near-white in dark — there is
    /// no one colour that works on both. A ring sits outside the problem.
    private func swatch(for option: AccentTheme) -> some View {
        let isSelected = option == accent
        return Circle()
            .fill(option.color)
            .frame(width: 30, height: 30)
            .overlay {
                Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
            .padding(4)
            .overlay {
                Circle()
                    .strokeBorder(option.color, lineWidth: 2)
                    .opacity(isSelected ? 1 : 0)
            }
    }

    /// One set of times for the whole app, not one per goal — see
    /// ``DailyCheckIns`` for the three reasons, one of which was a bug.
    @ViewBuilder
    private var reminders: some View {
        Section {
            Toggle("Daily reminders", isOn: $remindersEnabled)
                .accessibilityIdentifier("settings.reminders")

            if remindersEnabled, notificationsDenied {
                // iOS only ever shows its prompt once, so asking again does
                // nothing. Say where the switch actually is.
                Label {
                    Text("Notifications are off for Patch. Turn them on in Settings.")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.goalMissed)
                }
                .font(.caption)
            }

            if remindersEnabled {
                timeRows
                if times.count < DailyCheckIns.maximum {
                    Button("Add a time", systemImage: "plus") {
                        times += [DailyCheckIns.suggestedAddition(after: times)]
                        Haptics.play(.selection)
                    }
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("A nudge to open Patch and tick off your day — not one per goal.")
        }
    }

    /// Swipe-to-delete only appears once there are two, because a reminder
    /// list with nothing in it is a switch that is on and does nothing.
    @ViewBuilder
    private var timeRows: some View {
        let rows = ForEach(times, id: \.self) { time in
            DatePicker(
                "Time",
                selection: binding(for: time),
                displayedComponents: .hourAndMinute
            )
            .accessibilityIdentifier("reminder.\(ReminderPlanner.identifier(for: time))")
        }

        if times.count > 1 {
            rows.onDelete { offsets in
                times = times.enumerated()
                    .filter { !offsets.contains($0.offset) }
                    .map(\.element)
            }
        } else {
            rows
        }
    }

    private var times: [Reminder] {
        get { DailyCheckIns.parse(reminderTimesRaw) }
        nonmutating set { reminderTimesRaw = DailyCheckIns.text(newValue) }
    }

    /// Bound by value rather than by index: editing a time re-sorts the list,
    /// so the row an index pointed at a moment ago may now be a different one.
    private func binding(for time: Reminder) -> Binding<Date> {
        Binding(
            get: { Self.date(from: time) },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                guard let hour = parts.hour, let minute = parts.minute else { return }
                let replacement = Reminder(hour: hour, minute: minute)
                times = times.map { $0 == time ? replacement : $0 }
            }
        )
    }

    private static func date(from reminder: Reminder) -> Date {
        Calendar.current.date(
            from: DateComponents(hour: reminder.hour, minute: reminder.minute)
        ) ?? .now
    }

    private func syncReminders() async {
        await scheduler.sync(times: times, isEnabled: remindersEnabled)
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

#Preview {
    SettingsView()
}
