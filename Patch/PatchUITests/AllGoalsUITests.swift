import XCTest

/// Covers the hole a tester found: a goal scheduled for days other than today
/// was unreachable — not visible on Today, so not editable and not
/// archivable. Archived goals were in the same position permanently.
final class AllGoalsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEveryGoalIsReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-state", "-demo-data"]
        app.launch()
        XCTAssertTrue(app.buttons["today.settings"].waitForExistence(timeout: 20), "No Today screen")

        // Demo data includes a goal on a day-of-month schedule and a
        // weekday-only one, so on most days at least one goal is missing
        // from Today and must still be listed here.
        app.buttons["today.settings"].tap()
        XCTAssertTrue(app.buttons["settings.allGoals"].waitForExistence(timeout: 10), "No settings")
        app.buttons["settings.allGoals"].tap()
        sleep(2)
        attach(app.screenshot(), named: "1-all-goals")

        for title in ["Read", "Water", "Push-ups", "Gym", "Save money", "Coffee"] {
            XCTAssertTrue(
                app.staticTexts[title].exists,
                "\(title) was missing from the list that is supposed to be complete"
            )
        }
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
