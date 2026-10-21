import XCTest

/// Deleting an archived goal — the one irreversible action in the app.
///
/// Photographs the confirmation, because what a `confirmationDialog`
/// actually renders is not obvious from the code: it supplies its own cancel
/// in some configurations and uses the one you give it in others.
final class DeleteGoalUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDeletingAnArchivedGoal() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-state", "-demo-data"]
        app.launch()
        XCTAssertTrue(app.buttons["today.allGoals"].waitForExistence(timeout: 20), "No Today screen")
        app.buttons["today.allGoals"].tap()
        sleep(2)

        let water = app.cells.containing(.staticText, identifier: "Water").firstMatch
        XCTAssertTrue(water.waitForExistence(timeout: 5), "No Water goal")

        // A running goal must not offer Delete at all.
        water.press(forDuration: 1.2)
        sleep(2)
        attach(app.screenshot(), named: "1-menu-active")
        XCTAssertFalse(app.buttons["Delete"].exists, "Delete was offered on a goal that is not archived")

        app.buttons["Archive"].tap()
        sleep(2)

        // Now it should, behind a confirmation.
        app.cells.containing(.staticText, identifier: "Water").firstMatch.press(forDuration: 1.2)
        sleep(2)
        attach(app.screenshot(), named: "2-menu-archived")
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3), "No Delete on an archived goal")
        app.buttons["Delete"].tap()
        sleep(2)
        attach(app.screenshot(), named: "3-confirmation")

        XCTAssertTrue(
            app.buttons["Cancel"].waitForExistence(timeout: 3),
            "The confirmation offered no way out"
        )
        app.buttons["Cancel"].tap()
        sleep(2)
        XCTAssertTrue(app.staticTexts["Water"].exists, "Cancel deleted it anyway")
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
