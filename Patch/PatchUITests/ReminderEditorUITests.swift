import XCTest

/// Checks the reminder controls exist and behave. Persistence is covered by
/// the store round-trip test; this is only about the editor. Out of CI: needs
/// a simulator.
final class ReminderEditorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTurningOnAReminderRevealsATime() throws {
        let app = XCUIApplication()
        app.launch()

        // Past onboarding if this is a clean install.
        let onboarding = app.buttons["onboarding.primary"]
        if onboarding.waitForExistence(timeout: 10) {
            onboarding.tap()
            sleep(1)
            onboarding.tap()
            sleep(2)
        }

        let add = app.buttons["Add goal"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10), "No way to open the editor")
        add.tap()

        let toggle = app.switches["Remind me"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "No reminder control in the editor")
        XCTAssertFalse(
            app.datePickers.firstMatch.exists,
            "A time picker was showing before a reminder was asked for"
        )
        attach(app.screenshot(), named: "1-reminder-off")

        // Tapped at the switch end of the row: a plain `tap()` on a Form's
        // Toggle lands on the row and does not always flip it.
        flip(toggle)
        XCTAssertTrue(
            app.datePickers.firstMatch.waitForExistence(timeout: 5),
            "Turning the reminder on did not reveal a time"
        )
        attach(app.screenshot(), named: "2-reminder-on")

        flip(toggle)
        sleep(1)
        XCTAssertFalse(
            app.datePickers.firstMatch.exists,
            "Turning the reminder off left the time behind"
        )
    }

    private func flip(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
