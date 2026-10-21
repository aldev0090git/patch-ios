import XCTest

/// Reported from a device: a goal saved for Tuesday and Thursday reopened
/// showing Monday, Wednesday and Friday.
///
/// The store round-trips those days correctly — `weekdayRoundTrip` in
/// `PatchStoreTests` pins that — so if the bug is real it is in the editor,
/// and only driving the editor can show it.
///
/// The goal is given a schedule that *includes today*, because a goal
/// scheduled only for other days cannot be reopened at all. That is its own
/// bug, reported alongside this one.
final class ScheduleEditingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testChosenWeekdaysComeBack() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-state", "-demo-data"]
        app.launch()
        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 20), "No Today screen")

        app.buttons["today.add"].tap()
        XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 10), "No editor")

        app.textFields.firstMatch.tap()
        app.textFields.firstMatch.typeText("Weekday test")

        // Scroll to the Repeat section and switch to specific weekdays.
        while !app.buttons["Certain days"].exists {
            app.swipeUp()
        }
        app.buttons["Certain days"].tap()
        sleep(1)
        scrollToWeekdays(app)

        // Every weekday starts selected; clear them, then pick a set that
        // includes today so the goal is reachable afterwards.
        let wanted: Set<Int> = [3, 4, 5]   // Tue, Wed, Thu — Weekday rawValues
        for raw in 1...7 {
            let button = app.buttons["weekday.\(raw)"]
            guard button.exists else { continue }
            let selected = button.isSelected
            if selected != wanted.contains(raw) { button.tap() }
        }
        sleep(1)
        attach(app.screenshot(), named: "1-chosen")

        let chosen = selectedWeekdays(app)
        XCTAssertEqual(chosen, wanted, "The picker did not end up in the state we asked for")

        app.buttons["editor.save"].tap()
        sleep(3)
        attach(app.screenshot(), named: "2-today-after-save")

        // Reopen it. New goals sort last, so it may be below the fold.
        let row = app.staticTexts["Weekday test"].firstMatch
        for _ in 0..<6 where !row.exists {
            app.swipeUp()
            sleep(1)
        }
        attach(app.screenshot(), named: "3-looking-for-it")
        XCTAssertTrue(row.exists, "A goal scheduled for today was not on Today after saving")
        row.press(forDuration: 1.2)
        sleep(2)
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 10), "No editor")
        while !app.buttons["Certain days"].exists {
            app.swipeUp()
        }
        scrollToWeekdays(app)
        sleep(1)
        attach(app.screenshot(), named: "4-reopened")

        XCTAssertEqual(
            selectedWeekdays(app), wanted,
            "Reopening the editor showed different days from the ones saved"
        )
    }

    @MainActor
    private func selectedWeekdays(_ app: XCUIApplication) -> Set<Int> {
        // `exists` first: `isSelected` on an element that is not in the tree
        // raises rather than returning false, which turns "the chips are
        // still below the fold" into an unreadable snapshot failure.
        Set((1...7).filter {
            let button = app.buttons["weekday.\($0)"]
            return button.exists && button.isSelected
        })
    }

    /// Scrolls until the weekday chips are built. They sit below the Repeat
    /// picker, so reaching "Certain days" does not mean reaching them.
    @MainActor
    private func scrollToWeekdays(_ app: XCUIApplication) {
        for _ in 0..<4 where !app.buttons["weekday.1"].exists {
            app.swipeUp()
            sleep(1)
        }
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
