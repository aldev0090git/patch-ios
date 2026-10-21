import XCTest

/// Captures the screenshots the README uses, in both appearances.
///
/// Not part of CI: it needs a simulator, and it exists to produce images
/// rather than to assert much. It does assert each screen arrived, so a
/// README picture can never be of a blank page.
///
/// The theme is set through launch arguments rather than through the Settings
/// screen, because `UserDefaults` reads `-key value` pairs straight off the
/// command line — so this drives the app's real stored setting, not a test-only
/// back door. `-demo-data` goes **last**: it is a bare flag, and `UserDefaults`
/// would otherwise swallow the key after it as its value.
final class ScreenshotUITests: XCTestCase {
    /// Light pairs with the default accent, dark with another one, so the two
    /// sets of images together show that the accent is a real setting rather
    /// than a repaint of the chrome.
    private enum Look: String {
        case light
        case dark

        var accent: String { self == .light ? "blue" : "violet" }

        var arguments: [String] {
            ["-appearance", rawValue, "-accentTheme", accent]
        }

        /// Set `PATCH_UI_LANGUAGE` to check a translation in place. Unset for
        /// the README captures, which are English.
        static var language: [String] {
            guard let code = ProcessInfo.processInfo.environment["PATCH_UI_LANGUAGE"] else {
                return []
            }
            return ["-AppleLanguages", "(\(code))", "-AppleLocale", code]
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testCaptureOnboardingLight() { captureOnboarding(.light) }
    @MainActor func testCaptureOnboardingDark() { captureOnboarding(.dark) }
    @MainActor func testCaptureScreensLight() { captureScreens(.light) }
    @MainActor func testCaptureScreensDark() { captureScreens(.dark) }
    @MainActor func testCaptureEditor() { captureEditor(.light) }
    @MainActor func testCaptureAllGoals() { captureAllGoals(.light) }

    /// Every goal, scheduled today or not — the screen that exists because a
    /// goal set to Tuesdays could not be reached on a Wednesday.
    @MainActor
    private func captureAllGoals(_ look: Look) {
        let app = XCUIApplication()
        app.launchArguments = Look.language + look.arguments + ["-reset-state", "-demo-data"]
        app.launch()

        let allGoals = app.buttons["today.allGoals"]
        XCTAssertTrue(allGoals.waitForExistence(timeout: 15), "No Today screen")
        allGoals.tap()
        sleep(2)

        // Archive one, so the screenshot shows both states rather than a
        // list that looks the same as Today's.
        let coffee = app.cells.containing(.staticText, identifier: "Coffee").firstMatch
        if coffee.waitForExistence(timeout: 5) {
            coffee.press(forDuration: 1.2)
            sleep(2)
            if app.buttons["Archive"].waitForExistence(timeout: 3) {
                app.buttons["Archive"].tap()
                sleep(2)
            }
        }
        attach(app.screenshot(), named: "\(look.rawValue)-14-all-goals")
    }

    /// The goal editor and the reminder settings, which the README set does
    /// not cover and which are the two densest forms in the app — the places
    /// a translation is most likely to overflow a row.
    @MainActor
    private func captureEditor(_ look: Look) {
        let app = XCUIApplication()
        app.launchArguments = Look.language + look.arguments + ["-reset-state", "-demo-data"]
        app.launch()

        // Identifiers, not labels, throughout this one: it is the test that
        // gets run against a translation, and every label it could name is
        // translated.
        let add = app.buttons["today.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "No Today screen")
        add.tap()
        XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 10), "No goal editor")
        sleep(1)
        attach(app.screenshot(), named: "\(look.rawValue)-10-editor-top")

        app.swipeUp()
        sleep(1)
        attach(app.screenshot(), named: "\(look.rawValue)-11-editor-bottom")

        // The Apple Health row, which says what it will read rather than
        // offering a switch with no subject.
        let health = app.buttons["editor.health"]
        for _ in 0..<4 where !health.exists {
            app.swipeUp()
            sleep(1)
        }
        if health.exists {
            // Captured in its Off state deliberately. Choosing a source puts
            // up the system Health permission sheet — correct behaviour, it
            // asks at the moment you choose — so a capture that picked one
            // would photograph iOS's sheet instead of this row, and the test
            // would then be stuck behind it.
            attach(app.screenshot(), named: "\(look.rawValue)-13-health")
        }

        app.buttons["editor.cancel"].tap()
        sleep(1)
        app.buttons["today.settings"].tap()
        let reminders = app.switches["settings.reminders"]
        XCTAssertTrue(reminders.waitForExistence(timeout: 10), "No reminder setting")
        // Tapping the row lands on the row; the switch end is what flips it.
        reminders.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        sleep(2)
        attach(app.screenshot(), named: "\(look.rawValue)-12-reminders")
    }

    /// Onboarding only exists on a clean install, and demo data skips it, so
    /// it gets its own run with no goals in the store.
    @MainActor
    private func captureOnboarding(_ look: Look) {
        let app = XCUIApplication()
        app.launchArguments = Look.language + look.arguments + ["-reset-state"]
        app.launch()

        let onboarding = app.buttons["onboarding.primary"]
        XCTAssertTrue(onboarding.waitForExistence(timeout: 10), "Onboarding did not appear")
        attach(app.screenshot(), named: "\(look.rawValue)-01-welcome")

        onboarding.tap()
        sleep(1)
        attach(app.screenshot(), named: "\(look.rawValue)-02-shapes")

        onboarding.tap()
        sleep(1)
        attach(app.screenshot(), named: "\(look.rawValue)-03-choose")

        onboarding.tap()
        sleep(1)
        attach(app.screenshot(), named: "\(look.rawValue)-04-how-it-works")
    }

    @MainActor
    private func captureScreens(_ look: Look) {
        let app = XCUIApplication()
        app.launchArguments = Look.language + look.arguments + ["-reset-state", "-demo-data"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 10), "No Today screen")
        attach(app.screenshot(), named: "\(look.rawValue)-04-today")

        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.buttons["calendar.previousMonth"].waitForExistence(timeout: 10), "No Calendar screen")
        sleep(1)
        attach(app.screenshot(), named: "\(look.rawValue)-05-calendar")

        app.tabBars.buttons["Statistics"].tap()
        XCTAssertTrue(app.staticTexts["Statistics"].waitForExistence(timeout: 10), "No Statistics screen")
        sleep(1)
        attach(app.screenshot(), named: "\(look.rawValue)-06-statistics")

        // A month also covers the twice-a-month saving goal, which is where
        // the long-run target and its deadline show up.
        app.buttons["Period"].firstMatch.tap()
        sleep(1)
        app.buttons["Month"].firstMatch.tap()
        sleep(2)
        attach(app.screenshot(), named: "\(look.rawValue)-07-statistics-month")

        // The saving goal sits at the bottom, and it is the one carrying the
        // long-run target and its deadline.
        app.swipeUp()
        sleep(1)
        attach(app.screenshot(), named: "\(look.rawValue)-08-overall-goal")

        app.tabBars.buttons["Today"].tap()
        sleep(1)
        app.buttons["Settings"].firstMatch.tap()
        let accent = app.buttons["accent.\(look.accent)"]
        XCTAssertTrue(accent.waitForExistence(timeout: 10), "No Settings screen")
        // The swatch for the accent this run was launched with must already be
        // the selected one — which is also the proof that the launch argument
        // reached the real setting rather than only the chrome.
        XCTAssertTrue(accent.isSelected, "Settings does not show the accent the app launched with")
        sleep(1)
        attach(app.screenshot(), named: "\(look.rawValue)-09-settings")
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
