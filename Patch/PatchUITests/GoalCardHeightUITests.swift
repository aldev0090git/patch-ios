import XCTest

/// Pins the invariant that fixed the reset glitch.
///
/// A goal card must be exactly as tall when it is done as when it is not.
/// When the height changed, `UITableView` animated the row height underneath
/// SwiftUI — scaling the card up and drawing it across its neighbour, because
/// `List` does not clip rows. No amount of turning SwiftUI animations off
/// touched it; the only fix was to stop the height changing.
///
/// **The card being watched must sit below the card being changed.** An
/// earlier version of this test changed Push-ups and watched Water, which is
/// above it — so nothing it asserted could have moved, whatever the card did.
/// It also relied on whatever goals a previous test happened to leave behind,
/// and failed outright on a clean install. Both are why it now launches with
/// the demo data and names its cards deliberately.
///
/// Out of CI like the other UI tests: it needs a simulator.
final class GoalCardHeightUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFinishingAndResettingAGoalDoNotChangeItsCardHeight() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-state", "-demo-data"]
        app.launch()

        // Read is first and part-finished; Push-ups is below it, so it moves
        // if Read's card changes height in either direction.
        let below = app.staticTexts["Push-ups"].firstMatch
        XCTAssertTrue(below.waitForExistence(timeout: 15), "No Today screen")
        let origin = below.frame.origin.y

        let finish = app.buttons["20 min"].firstMatch
        XCTAssertTrue(finish.waitForExistence(timeout: 5), "Read offered no way to finish it")
        finish.tap()
        sleep(1)

        // The done half of the footer now carries an "Add more" button, which
        // is the control most likely to make that half the taller one.
        XCTAssertTrue(
            app.buttons["card.addMore"].firstMatch.exists,
            "A finished goal offered no way to log past its target"
        )
        XCTAssertEqual(
            below.frame.origin.y, origin, accuracy: 0.5,
            "Finishing a goal moved the card below it, so the card changed height"
        )

        // And back again, which is the direction that actually glitched.
        //
        // Dragged across the whole card rather than `swipeLeft()` on the
        // title: a swipe covers the element it starts from, and "Read" is a
        // short word, so the gesture was too short to open the row actions.
        let card = app.cells.element(boundBy: 0)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.3))
            .press(
                forDuration: 0.05,
                thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.3))
            )
        let reset = app.buttons["Reset"].firstMatch
        XCTAssertTrue(reset.waitForExistence(timeout: 5), "No Reset action on a logged goal")
        reset.tap()
        sleep(1)

        XCTAssertEqual(
            below.frame.origin.y, origin, accuracy: 0.5,
            "Resetting a goal moved the card below it, so the card changed height"
        )
    }
}
