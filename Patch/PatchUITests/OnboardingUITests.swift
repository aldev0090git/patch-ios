import XCTest

/// Walks the first-run flow on a clean install. Out of CI: needs a simulator.
final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstRunCreatesTheChosenGoals() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-state", "-AppleLanguages", "(uk)", "-AppleLocale", "uk_UA"]
        app.launch()

        let primary = app.buttons["onboarding.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 15), "Onboarding did not appear")
        attach(app.screenshot(), named: "1-welcome")

        primary.tap()          // Get started
        sleep(1)
        XCTAssertTrue(app.staticTexts["Якою може бути ціль"].waitForExistence(timeout: 5),
                      "The goal-shapes page did not appear")
        attach(app.screenshot(), named: "2-shapes")

        primary.tap()          // Continue
        sleep(1)
        attach(app.screenshot(), named: "3-picker")

        primary.tap()          // Continue
        sleep(1)
        XCTAssertTrue(app.staticTexts["Як це працює"].waitForExistence(timeout: 5),
                      "The how-it-works page did not appear")
        attach(app.screenshot(), named: "4-how-it-works")

        primary.tap()          // Track the preselected goals
        sleep(2)
        attach(app.screenshot(), named: "5-today")

        // The three suggested goals, and the tab bar behind them.
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).waitForExistence(timeout: 10),
                      "Finishing onboarding did not reach the app")
        XCTAssertFalse(primary.exists, "Onboarding was still on screen after finishing")
        for title in ["Читати", "Вода", "Кроки"] {
            XCTAssertTrue(app.staticTexts[title].exists, "\(title) was not created")
        }
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
