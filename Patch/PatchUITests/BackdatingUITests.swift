import XCTest

/// Logging against a day that has already passed, through the real screens.
///
/// The model tests cover what may be written where; this covers the thing
/// they cannot — that the controls exist, that tapping one reaches the store,
/// and that the row on screen changes afterwards.
final class BackdatingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLoggingAPastDayChangesTheRow() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo-data"]
        app.launch()

        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 10), "No Today screen")
        app.tabBars.buttons.element(boundBy: 1).tap()

        // The 1st is always in the month on screen and never in the future,
        // and the demo data starts two months back, so every goal already
        // existed by then.
        let firstOfMonth = app.descendants(matching: .any)
            .matching(identifier: "calendar.day.1").firstMatch
        XCTAssertTrue(firstOfMonth.waitForExistence(timeout: 10), "No calendar grid")
        firstOfMonth.tap()

        let rows = app.descendants(matching: .any).matching(identifier: "day.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "The selected day offered no goals to log")
        attach(app.screenshot(), named: "1-day-selected")

        // The label carries the goal, its amount and whether it is done, so a
        // change to it is proof the entry reached the store and came back.
        let before = rows.firstMatch.label
        rows.firstMatch.tap()

        // An incremental goal opens the amount picker; a once-a-day goal
        // toggles there and then.
        let add = app.buttons["Add"]
        if add.waitForExistence(timeout: 3) {
            attach(app.screenshot(), named: "2-amount-picker")
            add.tap()
        }

        sleep(2)
        attach(app.screenshot(), named: "3-after-logging")
        XCTAssertNotEqual(
            rows.firstMatch.label, before,
            "Logging a past day did not change the row"
        )
    }

    @MainActor
    func testAPastDayCanBeClearedFromTheRow() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo-data"]
        app.launch()

        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 10), "No Today screen")
        app.tabBars.buttons.element(boundBy: 1).tap()

        let firstOfMonth = app.descendants(matching: .any)
            .matching(identifier: "calendar.day.1").firstMatch
        XCTAssertTrue(firstOfMonth.waitForExistence(timeout: 10), "No calendar grid")
        firstOfMonth.tap()

        // Visible on the row, not only behind a long press — a way to undo
        // that only the author knows about is not a way to undo.
        let clear = app.descendants(matching: .any).matching(identifier: "day.clear").firstMatch
        XCTAssertTrue(clear.waitForExistence(timeout: 5), "No visible way to clear a logged day")

        // Every row, not the first one: the clear button belongs to whichever
        // goal actually has something logged on that day, which is not
        // necessarily the row at the top.
        let rows = app.descendants(matching: .any).matching(identifier: "day.row")
        let before = (0..<rows.count).map { rows.element(boundBy: $0).label }
        clear.tap()
        sleep(2)
        let after = (0..<rows.count).map { rows.element(boundBy: $0).label }

        XCTAssertNotEqual(before, after, "Clearing a day changed nothing")
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
