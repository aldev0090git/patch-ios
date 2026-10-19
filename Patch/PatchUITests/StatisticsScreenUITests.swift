import XCTest

/// Drives the real app far enough to see the statistics screen with data on it.
///
/// Deliberately not part of the CI run — it needs a simulator and takes orders
/// of magnitude longer than the unit tests. It exists to catch the things unit
/// tests cannot: a tab that does not appear, a screen that renders empty
/// because the model never reloaded.
final class StatisticsScreenUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLoggingOnTodayShowsUpInStatistics() throws {
        // Demo data rather than whatever a previous test left behind: on an
        // empty store the onboarding cover sits over everything, and logging
        // one goal by hand left the window's contents depending on test order.
        let app = XCUIApplication()
        app.launchArguments = ["-reset-state", "-demo-data"]
        app.launch()

        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 15), "No Today screen")
        app.tabBars.buttons["Statistics"].tap()

        // The heading only renders once the model has loaded and found rows.
        XCTAssertTrue(
            app.staticTexts["Statistics"].waitForExistence(timeout: 10),
            "The statistics screen did not appear"
        )

        attach(app.screenshot(), named: "Statistics")

        // A window from before any goal existed has nothing to say, and must
        // say so rather than rendering a wall of 0%. The demo history starts
        // about nine weeks back, so twelve steps is safely before it.
        for _ in 0..<12 {
            app.buttons["Previous period"].tap()
        }
        XCTAssertTrue(
            app.staticTexts["Nothing to report yet"].waitForExistence(timeout: 5),
            "An empty window did not show the empty state"
        )
        attach(app.screenshot(), named: "Statistics - empty window")
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
