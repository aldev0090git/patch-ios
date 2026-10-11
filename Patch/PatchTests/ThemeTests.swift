import SwiftUI
import Testing
@testable import Patch

@Suite("Appearance")
struct AppearanceTests {
    @Test("System means don't force a scheme; the other two do")
    func schemeMapping() {
        #expect(Appearance.system.colorScheme == nil)
        #expect(Appearance.light.colorScheme == .light)
        #expect(Appearance.dark.colorScheme == .dark)
    }

    @Test("Raw values are a storage format and must not drift")
    func rawValuesAreStable() {
        // These strings are in every user's UserDefaults. Renaming a case
        // without noticing would quietly put everyone back on System.
        #expect(Appearance.allCases.map(\.rawValue) == ["system", "light", "dark"])
    }

    @MainActor
    @Test("Every appearance has something to show in the picker")
    func titlesExist() {
        for option in Appearance.allCases {
            #expect(!option.title.isEmpty)
        }
    }
}

@Suite("Accent theme")
struct AccentThemeTests {
    @Test("Raw values are a storage format and must not drift")
    func rawValuesAreStable() {
        #expect(
            AccentTheme.allCases.map(\.rawValue)
                == ["blue", "indigo", "violet", "teal", "rose", "graphite"]
        )
    }

    @Test("A stored colour this build no longer offers falls back rather than failing")
    func unknownValueFallsBack() {
        // An install that chose a colour a later build dropped should open on
        // the default, not refuse to open.
        #expect(AccentTheme.stored("chartreuse") == .blue)
        #expect(AccentTheme.stored("teal") == .teal)
    }

    @MainActor
    @Test("Every accent has a name for the picker and for VoiceOver")
    func titlesExist() {
        for option in AccentTheme.allCases {
            #expect(!option.title.isEmpty)
        }
    }

    @MainActor
    @Test("No two accents are the same colour")
    func coloursAreDistinct() {
        // Resolved against a fixed environment, because `.primary` and the
        // system colours mean different things in light and dark.
        let environment = EnvironmentValues()
        let resolved = AccentTheme.allCases.map { $0.color.resolve(in: environment) }
        #expect(Set(resolved).count == AccentTheme.allCases.count)
    }
}

@Suite("Haptics settings", .serialized)
struct HapticsSettingsTests {
    /// Restores whatever was there, because `UserDefaults.standard` outlives
    /// the test and the simulator keeps it between runs.
    private func withStoredHaptics<T>(_ value: Bool?, _ body: () throws -> T) rethrows -> T {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: SettingsKey.haptics)
        defer { defaults.set(original, forKey: SettingsKey.haptics) }

        if let value {
            defaults.set(value, forKey: SettingsKey.haptics)
        } else {
            defaults.removeObject(forKey: SettingsKey.haptics)
        }
        return try body()
    }

    @MainActor
    @Test("A fresh install vibrates — the setting being absent is not the same as off")
    func defaultsToOn() {
        withStoredHaptics(nil) {
            #expect(Haptics.isEnabled)
        }
    }

    @MainActor
    @Test("Switching it off is honoured")
    func respectsTheToggle() {
        withStoredHaptics(false) {
            #expect(!Haptics.isEnabled)
        }
        withStoredHaptics(true) {
            #expect(Haptics.isEnabled)
        }
    }
}
