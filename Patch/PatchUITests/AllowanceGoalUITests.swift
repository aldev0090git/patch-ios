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
        app.launchArguments = ["-demo-data"]
        app.launch()

        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 10), "No Today screen")

        // "Within limit" is unique to the one `atMost` goal in the demo data,
        // as are its bare "1" and "2" buttons — every other goal's amounts
        // carry a unit or read "Done".
        let state = app.staticTexts["Within limit"]
        XCTAssertTrue(state.waitForExistence(timeout: 5), "No allowance goal on Today")

        let one = app.buttons["1"]
        XCTAssertTrue(
            one.waitForExistence(timeout: 5),
            "An allowance goal inside its limit offered no way to log against it"
        )

        // Demo data starts the day on one cup against a limit of two, so two
        // more takes it over.
        one.tap()
        one.tap()

        XCTAssertTrue(
            app.staticTexts["Over the limit"].waitForExistence(timeout: 5),
            "Logging past the limit did not fail the day"
        )
    }
}
