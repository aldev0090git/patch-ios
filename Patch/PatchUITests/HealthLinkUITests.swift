import XCTest

/// Proves the Apple Health row appears for the measures a phone can actually
/// count, and goes away for the ones it cannot.
///
/// Worth a UI test rather than a unit test for one reason: whether the row
/// exists at all depends on `HKHealthStore.isHealthDataAvailable()`, which is
/// a property of the running device and cannot be faked. The simulator does
/// ship Health.app and HealthKit.framework, so this runs — but it only ever
/// checks the *shape* of the screen. Whether real step data arrives is a
/// question for a real phone.
final class HealthLinkUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTheHealthRowFollowsTheChosenMeasure() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-state", "-demo-data"]
        app.launch()

        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 15), "No Today screen")
        app.buttons["today.add"].tap()
        XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 10), "No goal editor")

        // A new goal starts as a time goal, which Health can fill from the
        // exercise ring.
        // Any element type, not `.switches`: this row started as a
        // toggle and is now a menu picker, because a count goal has to say
        // *which* count — steps and push-ups are both `.count`.
        let healthToggle = app.descendants(matching: .any)
            .matching(identifier: "editor.health").firstMatch
        XCTAssertTrue(
            healthToggle.waitForExistence(timeout: 5),
            "A time goal should offer Apple Health — is HealthKit missing from this runtime?"
        )
        attach(app.screenshot(), named: "1-health-row-for-time")

        // Money is the case the row must not appear for: no phone counts it.
        selectMeasure("Money", in: app)
        XCTAssertTrue(
            app.staticTexts["Currency"].waitForExistence(timeout: 5),
            "The measure did not change to money"
        )
        XCTAssertFalse(
            healthToggle.exists,
            "A money goal offered to fill itself in from Apple Health"
        )
        attach(app.screenshot(), named: "2-no-health-row-for-money")

        // Count is a phone's own best measure, and the one the Steps template
        // uses, so it must come back.
        selectMeasure("Count", in: app)
        XCTAssertTrue(
            healthToggle.waitForExistence(timeout: 5),
            "A count goal should offer Apple Health"
        )
        attach(app.screenshot(), named: "3-health-row-for-count")
    }

    /// Opens the Measure menu and picks an option.
    ///
    /// The picker is identified; its options are not, so they are matched by
    /// label — which is safe only because this test does not set a language
    /// and therefore runs in English.
    @MainActor
    private func selectMeasure(_ option: String, in app: XCUIApplication) {
        let picker = app.buttons["editor.measure"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "No measure picker")
        picker.tap()
        let choice = app.buttons[option].firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5), "The menu had no \(option) option")
        choice.tap()
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
