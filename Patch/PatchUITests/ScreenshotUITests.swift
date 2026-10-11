import XCTest

/// Captures the screenshots the README uses.
///
/// Not part of CI: it needs a simulator, and it exists to produce images
/// rather than to assert much. It does assert each screen arrived, so a
/// README picture can never be of a blank page.
final class ScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Onboarding only exists on a clean install, and demo data skips it, so
    /// it gets its own run.
    @MainActor
    func testCaptureOnboarding() throws {
        let app = XCUIApplication()
        app.launch()

        let onboarding = app.buttons["onboarding.primary"]
        XCTAssertTrue(onboarding.waitForExistence(timeout: 10), "Onboarding did not appear")
        attach(app.screenshot(), named: "01-welcome")

        onboarding.tap()
        sleep(1)
        attach(app.screenshot(), named: "02-choose")

        onboarding.tap()
        sleep(1)
        attach(app.screenshot(), named: "03-how-it-works")
    }

    @MainActor
    func testCaptureScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo-data"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 10), "No Today screen")
        attach(app.screenshot(), named: "04-today")

        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.staticTexts["Calendar"].waitForExistence(timeout: 10), "No Calendar screen")
        sleep(1)
        attach(app.screenshot(), named: "05-calendar")

        app.tabBars.buttons["Statistics"].tap()
        XCTAssertTrue(app.staticTexts["Statistics"].waitForExistence(timeout: 10), "No Statistics screen")
        sleep(1)
        attach(app.screenshot(), named: "06-statistics")

        // A month also covers the twice-a-month saving goal, which is where
        // the long-run target and its deadline show up.
        app.buttons["Period"].firstMatch.tap()
        sleep(1)
        app.buttons["Month"].firstMatch.tap()
        sleep(2)
        attach(app.screenshot(), named: "07-statistics-month")

        // The saving goal sits at the bottom, and it is the one carrying the
        // long-run target and its deadline.
        app.swipeUp()
        sleep(1)
        attach(app.screenshot(), named: "08-overall-goal")
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
