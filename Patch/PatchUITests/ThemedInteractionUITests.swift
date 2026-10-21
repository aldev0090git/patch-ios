import XCTest

/// Proves the app still works when a theme is on.
///
/// Written after a theme made Today impossible to scroll or tap: the pinned
/// header's background drew a screen-high gradient and, because `.clipped()`
/// clips drawing rather than hit testing, it stayed touch-sensitive over the
/// whole screen and swallowed everything beneath it.
///
/// `ThemePrototypeUITests` photographed all five themes and passed throughout,
/// because the only things it touched were the toolbar and the tab bar — both
/// of which sit outside the area that had broken. This one touches the middle
/// of the screen, which is where people actually use the app.
final class ThemedInteractionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testGoldIsUsable() { checkUsable(with: "gold") }
    @MainActor func testPaperIsUsable() { checkUsable(with: "paper") }
    @MainActor func testPlainIsUsable() { checkUsable(with: "plain") }

    @MainActor
    private func checkUsable(with theme: String) {
        let app = XCUIApplication()
        app.launchArguments = [
            "-appearance", "light", "-pageTheme", theme, "-reset-state", "-demo-data"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 20), "No Today screen")

        // A quick-add pill, in the body of the list rather than the chrome.
        let pill = app.buttons["20 min"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 10), "No quick-add pill to tap")
        XCTAssertTrue(pill.isHittable, "\(theme): the pill is on screen but cannot be tapped")

        let before = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'of 20 min'")
        ).firstMatch.label
        pill.tap()
        sleep(1)
        let after = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'of 20 min'")
        ).firstMatch.label
        XCTAssertNotEqual(before, after, "\(theme): tapping a quick-add pill logged nothing")

        // And the list still scrolls. Measured by watching a card move
        // rather than by looking for one further down: which goals are where
        // depends on the demo data, but a card that does not move means the
        // gesture never reached the list.
        let water = app.staticTexts["Water"].firstMatch
        XCTAssertTrue(water.waitForExistence(timeout: 10), "No Water card")
        let wasAt = water.frame.minY
        app.swipeUp()
        sleep(1)
        XCTAssertNotEqual(
            wasAt, water.frame.minY,
            "\(theme): Today would not scroll — the cards did not move"
        )
    }
}
