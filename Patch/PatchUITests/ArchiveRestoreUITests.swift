import XCTest

/// Archiving from All Goals moves the row from one section to another while
/// its swipe is still open, and the row was left stranded outside the
/// grouped card — drawn half off-screen with its action still showing.
final class ArchiveRestoreUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testArchivingThenRestoring() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-state", "-demo-data"]
        app.launch()
        XCTAssertTrue(app.buttons["today.settings"].waitForExistence(timeout: 20), "No Today screen")
        app.buttons["today.settings"].tap()
        XCTAssertTrue(app.buttons["settings.allGoals"].waitForExistence(timeout: 10), "No settings")
        app.buttons["settings.allGoals"].tap()
        sleep(2)

        // The cell, not the label: "Water" matches both the row's title and
        // the row itself, and a swipe needs one element.
        let water = app.cells.containing(.staticText, identifier: "Water").firstMatch
        XCTAssertTrue(water.waitForExistence(timeout: 5), "No Water goal")

        // Archive by long press — the menu is the primary route, and unlike a
        // swipe it cannot leave a half-open row behind when the list re-sorts.
        water.press(forDuration: 1.2)
        sleep(2)
        attach(app.screenshot(), named: "1-menu")
        XCTAssertTrue(app.buttons["Archive"].waitForExistence(timeout: 3), "No Archive action")
        app.buttons["Archive"].tap()
        sleep(3)
        attach(app.screenshot(), named: "2-after-archive")

        XCTAssertTrue(
            app.staticTexts["Archived"].waitForExistence(timeout: 5),
            "No Archived section after archiving"
        )

        // And back again.
        app.cells.containing(.staticText, identifier: "Water").firstMatch
            .press(forDuration: 1.2)
        sleep(2)
        XCTAssertTrue(app.buttons["Restore"].waitForExistence(timeout: 3), "No Restore action")
        app.buttons["Restore"].tap()
        sleep(3)
        attach(app.screenshot(), named: "3-after-restore")

        XCTAssertFalse(
            app.staticTexts["Archived"].exists,
            "The Archived section stayed after restoring the only archived goal"
        )
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
