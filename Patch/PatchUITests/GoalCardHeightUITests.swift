import XCTest

/// Pins the invariant that fixed the reset glitch.
///
/// A goal card must be exactly as tall when it is done as when it is not.
/// When the height changed, `UITableView` animated the row height underneath
/// SwiftUI — scaling the card up and drawing it across its neighbour, because
/// `List` does not clip rows. No amount of turning SwiftUI animations off
/// touched it; the only fix was to stop the height changing.
///
/// Out of CI like the other UI tests: it needs a simulator.
final class GoalCardHeightUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCompletingAGoalDoesNotChangeItsCardHeight() throws {
        let app = XCUIApplication()
        app.launch()

        // The card *below* the one being changed: if the changed card grows,
        // everything under it moves.
        let below = app.staticTexts["Water"].firstMatch
        XCTAssertTrue(below.waitForExistence(timeout: 15))
        let before = below.frame

        let complete = app.buttons["20"].firstMatch
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(app.staticTexts["Done for today"].waitForExistence(timeout: 5))

        XCTAssertEqual(
            below.frame.origin.y, before.origin.y, accuracy: 0.5,
            "Finishing a goal moved the card below it, so the card changed height"
        )

        // And back again, which is the direction that actually glitched.
        app.staticTexts["Push-ups"].firstMatch.swipeLeft()
        let reset = app.buttons["Reset"].firstMatch
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()
        sleep(1)

        XCTAssertEqual(
            below.frame.origin.y, before.origin.y, accuracy: 0.5,
            "Resetting a goal moved the card below it, so the card changed height"
        )
    }
}
