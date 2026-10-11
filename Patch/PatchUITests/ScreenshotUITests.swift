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
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testCaptureOnboardingLight() { captureOnboarding(.light) }
    @MainActor func testCaptureOnboardingDark() { captureOnboarding(.dark) }
    @MainActor func testCaptureScreensLight() { captureScreens(.light) }
    @MainActor func testCaptureScreensDark() { captureScreens(.dark) }

    /// Onboarding only exists on a clean install, and demo data skips it, so
    /// it gets its own run with no goals in the store.
    @MainActor
    private func captureOnboarding(_ look: Look) {
        let app = XCUIApplication()
        app.launchArguments = look.arguments
        app.launch()

        let onboarding = app.buttons["onboarding.primary"]
        XCTAssertTrue(onboarding.waitForExistence(timeout: 10), "Onboarding did not appear")
        attach(app.screenshot(), named: "\(look.rawValue)-01-welcome")

        onboarding.tap()
        sleep(1)
        attach(app.screenshot(), named: "\(look.rawValue)-02-choose")

        onboarding.tap()
        sleep(1)
        attach(app.screenshot(), named: "\(look.rawValue)-03-how-it-works")
    }

    @MainActor
    private func captureScreens(_ look: Look) {
        let app = XCUIApplication()
        app.launchArguments = look.arguments + ["-demo-data"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 10), "No Today screen")
        attach(app.screenshot(), named: "\(look.rawValue)-04-today")

        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.staticTexts["Calendar"].waitForExistence(timeout: 10), "No Calendar screen")
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
