import SwiftUI

/// Look and feel, plus the one bit of help worth keeping reachable.
///
/// A sheet off the Today screen rather than a fourth tab: a tab bar is for
/// places you go back to, and this is a place you visit twice a year. Three
/// tabs also stay legible at accessibility text sizes where four do not.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.appearance) private var appearance = Appearance.system
    @AppStorage(SettingsKey.accent) private var accent = AccentTheme.blue
    @AppStorage(SettingsKey.haptics) private var hapticsEnabled = true

    @State private var isShowingHowItWorks = false

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
        .animation(.snappy(duration: 0.25), value: accent)
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
