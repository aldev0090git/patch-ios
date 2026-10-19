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
        // Demo data rather than whatever a previous test left behind: on an
        // empty store the onboarding cover sits over everything and the tab
        // bar is never reachable.
        let app = XCUIApplication()
        app.launchArguments = ["-reset-state", "-demo-data"]
        app.launch()

        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 15), "No Today screen")
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(
            app.staticTexts["Calendar"].waitForExistence(timeout: 10),
            "The calendar screen did not appear"
        )
        attach(app.screenshot(), named: "Calendar")

        // Tapping today should open the day's goals underneath the grid.
        // By identifier, so it cannot land on a day borrowed from a
        // neighbouring month that happens to carry the same number.
        let today = Calendar.current.component(.day, from: Date())
        app.descendants(matching: .any)
            .matching(identifier: "calendar.day.\(today)").firstMatch.tap()
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
