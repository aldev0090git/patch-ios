import XCTest

/// Drives the calendar far enough to see the grid and a selected day.
/// Out of CI for the same reason as the statistics UI test: it needs a
/// simulator and is slow next to the unit tests.
final class CalendarScreenUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCalendarShowsTheMonthAndADaysGoals() throws {
        let app = XCUIApplication()
        app.launch()

        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 10) {
            done.tap()
        }

        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(
            app.staticTexts["Calendar"].waitForExistence(timeout: 10),
            "The calendar screen did not appear"
        )
        attach(app.screenshot(), named: "Calendar")

        // Tapping today should open the day's goals underneath the grid.
        let today = Calendar.current.component(.day, from: Date())
        app.staticTexts["\(today)"].firstMatch.tap()
        attach(app.screenshot(), named: "Calendar - day selected")

        app.buttons["Previous month"].tap()
        attach(app.screenshot(), named: "Calendar - previous month")
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
