import XCTest

/// Produces the App Store screenshots, at the one size Apple requires.
///
/// Separate from `ScreenshotUITests`, which makes the README pictures and
/// deliberately pairs dark mode with a second accent to prove the accent is a
/// real setting. A storefront wants the opposite: one accent throughout, so
/// the set reads as one app rather than as a palette.
///
/// Run on a **6.9" device** — iPhone 17 Pro Max or newer — which is 1320x2868,
/// the only size App Store Connect still requires for iPhone. Skipped in the
/// shared scheme like the other capture suites; run it by name.
final class AppStoreShotsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ appearance: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-appearance", appearance, "-accentTheme", "blue", "-pageTheme", "paper",
            "-reset-state", "-demo-data"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 20), "No Today screen")
        return app
    }

    @MainActor func testLightSet() { capture("light") }
    @MainActor func testDarkSet() { capture("dark") }

    @MainActor
    private func capture(_ appearance: String) {
        let app = launch(appearance)
        sleep(1)
        attach(app.screenshot(), named: "\(appearance)-1-today")

        // By position: the tab titles are translated.
        let tabs = app.tabBars.buttons
        tabs.element(boundBy: 1).tap()
        sleep(2)
        attach(app.screenshot(), named: "\(appearance)-2-calendar")

        tabs.element(boundBy: 2).tap()
        sleep(2)
        attach(app.screenshot(), named: "\(appearance)-3-statistics")

        // A month window is what shows the long-run target and its deadline;
        // the saving goal carrying them sits at the bottom.
        app.buttons["Period"].firstMatch.tap()
        sleep(1)
        app.buttons["Month"].firstMatch.tap()
        sleep(2)
        app.swipeUp()
        sleep(1)
        attach(app.screenshot(), named: "\(appearance)-4-overall-goal")
    }

    /// The widget, on a home screen, which is the only place it means
    /// anything. Drives SpringBoard, so it is slow and it is fragile — run it
    /// on a freshly booted device.
    @MainActor
    func testWidgetOnHomeScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-appearance", "light", "-accentTheme", "blue", "-pageTheme", "paper",
            "-reset-state", "-demo-data"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 20), "No Today screen")
        sleep(2)
        app.terminate()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        openGallery(in: springboard)

        let patch = springboard.staticTexts["Patch"].firstMatch
        guard patch.waitForExistence(timeout: 10) else {
            attach(springboard.screenshot(), named: "widget-gallery-missing")
            return XCTFail("Patch was not in the widget gallery")
        }
        // By coordinate: the label is inside a cell and reports itself as
        // not hittable, though the row takes the tap.
        patch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(3)

        // "Add Widget" places the selected size on the home screen.
        let add = springboard.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'add widget'")
        ).firstMatch
        guard add.waitForExistence(timeout: 10) else {
            attach(springboard.screenshot(), named: "widget-no-add-button")
            return XCTFail("No Add Widget button")
        }
        add.tap()
        sleep(4)

        // Placing leaves the home screen in editing mode, which draws jiggle
        // and a Done button over everything. Leave it before photographing.
        let done = springboard.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 5) {
            done.tap()
        } else {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()
        }
        sleep(4)
        attach(springboard.screenshot(), named: "widget-home-screen")
    }

    /// Long-press the home screen, Edit, then the Add Widget item inside the
    /// menu it opens. One tap is not enough; Edit only opens the menu.
    @MainActor
    private func openGallery(in springboard: XCUIApplication) {
        springboard.activate()
        sleep(3)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
            .press(forDuration: 1.6)
        sleep(3)

        if springboard.buttons["Edit"].waitForExistence(timeout: 5) {
            springboard.buttons["Edit"].tap()
            sleep(2)
        }
        let item = springboard.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'widget'")
        ).firstMatch
        if item.waitForExistence(timeout: 5) { item.tap() }
        sleep(4)

        // Search rather than scroll: the gallery list is built lazily, so an
        // app that has not rendered is absent from the tree entirely.
        let search = springboard.searchFields.firstMatch
        if search.waitForExistence(timeout: 10) {
            search.tap()
            search.typeText("Patch")
            sleep(3)
        }
    }

    @MainActor
    private func attach(_ shot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
