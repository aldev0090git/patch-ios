import XCTest

/// Photographs the goal card's context menu.
///
/// It exists because a destructive menu item is rendered by UIKit from a
/// SwiftUI description, and whether the role reaches the *image* as well as
/// the title is not something the code makes obvious — it has to be looked at.
final class ContextMenuUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTheCardMenu() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-state", "-demo-data"]
        app.launch()

        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 20), "No Today screen")

        // The third row: a goal that has been logged, so the menu shows all
        // three items rather than only Edit and Archive.
        let row = app.cells.element(boundBy: 2)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No goal rows")
        row.press(forDuration: 1.2)
        sleep(3)

        XCTAssertTrue(
            app.buttons["Archive"].waitForExistence(timeout: 5),
            "The context menu did not open"
        )
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "card-context-menu"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
