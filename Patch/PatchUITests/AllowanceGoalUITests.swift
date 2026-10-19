import XCTest

/// An `atMost` goal — "at most two coffees" — is inside its limit from
/// midnight, so "achieved" is true before anything has happened.
///
/// The Today card treated that as finished: it hid every control, which meant
/// the coffee could not be logged, which meant the goal could never fail. That
/// is the one thing an allowance exists to notice, so this pins it.
final class AllowanceGoalUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAnAllowanceGoalCanBeLoggedAndCanFail() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-state", "-demo-data"]
        app.launch()

        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 10), "No Today screen")

        // The demo allowance starts the day on one cup of two, and that
        // subtitle is unique to it — every other goal's amounts carry a unit.
        // It is also the thing that was broken: an allowance used to say
        // "Within limit" at nothing logged and at one of two alike, so logging
        // one looked like it had done nothing.
        XCTAssertTrue(
            app.staticTexts["1 of 2"].waitForExistence(timeout: 5),
            "An allowance goal showed no number, only a verdict"
        )

        let one = app.buttons["1"]
        XCTAssertTrue(
            one.waitForExistence(timeout: 5),
            "An allowance goal inside its limit offered no way to log against it"
        )

        // Demo data starts the day on one cup against a limit of two, so two
        // more takes it over.
        one.tap()
        one.tap()

        // Three of two: the number is its own warning, and the card turns
        // orange behind it.
        XCTAssertTrue(
            app.staticTexts["3 of 2"].waitForExistence(timeout: 5),
            "Logging past the limit did not fail the day"
        )
    }
}
