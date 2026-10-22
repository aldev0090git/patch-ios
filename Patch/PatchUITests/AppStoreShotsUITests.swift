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

    /// English (U.S.), pinned. These are the screenshots on the U.S. listing,
    /// and the machine making them is set to Ukraine — which formats dollars
    /// as "US$ 1 500" rather than "$1,500" even with the language in English.
    /// That is correct for a reader in Kharkiv and wrong on a storefront.
    private static let locale = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]

    @MainActor
    private func launch(_ appearance: String, theme: String = "paper") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = Self.locale + [
            "-appearance", appearance, "-accentTheme", "blue", "-pageTheme", theme,
            "-reset-state", "-demo-data"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 20), "No Today screen")
        return app
    }

    @MainActor func testLightSet() { capture("light", theme: "paper") }
    @MainActor func testDarkSet() { capture("dark", theme: "paper") }

    /// Every screen in every theme, dark. More than the listing uses — the
    /// compositor picks — but capturing is the slow part and choosing later
    /// is free.
    ///
    /// Here rather than in `ThemePrototypeUITests` so the whole store set
    /// shares one set of launch arguments; a slot in a different locale
    /// would be obvious in the row.
    @MainActor
    func testThemedSet() {
        for theme in ["gold", "roseGold", "platinum"] {
            capture("dark", theme: theme)
        }
    }

    @MainActor
    private func capture(_ appearance: String, theme: String) {
        let prefix = "\(appearance)-\(theme)"
        let app = launch(appearance, theme: theme)
        sleep(1)
        attach(app.screenshot(), named: "\(prefix)-1-today")

        // By position: the tab titles are translated.
        let tabs = app.tabBars.buttons
        tabs.element(boundBy: 1).tap()
        sleep(2)
        attach(app.screenshot(), named: "\(prefix)-2-calendar")

        tabs.element(boundBy: 2).tap()
        sleep(2)
        attach(app.screenshot(), named: "\(prefix)-3-statistics")

        // A month window is what shows the long-run target and its deadline;
        // the saving goal carrying them sits at the bottom.
        app.buttons["Period"].firstMatch.tap()
        sleep(1)
        app.buttons["Month"].firstMatch.tap()
        sleep(2)
        app.swipeUp()
        sleep(1)
        attach(app.screenshot(), named: "\(prefix)-4-overall-goal")
    }

    /// The widget, on a home screen, which is the only place it means
    /// anything. Drives SpringBoard, so it is slow and it is fragile — run it
    /// on a freshly booted device.
    ///
    /// The *system* appearance decides how the widget renders, not the app's,
    /// so set it before running:
    /// `xcrun simctl ui <udid> appearance dark`.
    @MainActor
    func testWidgetOnHomeScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = Self.locale + [
            "-appearance", "dark", "-accentTheme", "blue", "-pageTheme", "platinum",
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
        try place(in: springboard, swipes: 0)   // small

        openGallery(in: springboard)
        let again = springboard.staticTexts["Patch"].firstMatch
        guard again.waitForExistence(timeout: 10) else {
            return XCTFail("Patch left the gallery between placements")
        }
        again.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(3)
        try place(in: springboard, swipes: 1)   // medium

        attach(springboard.screenshot(), named: "widget-home-screen")
    }

    /// Places one widget. The sizes are a carousel opening on the small one,
    /// so `swipes` chooses which: 0 small, 1 medium.
    @MainActor
    private func place(in springboard: XCUIApplication, swipes: Int) throws {
        for _ in 0..<swipes {
            springboard.swipeLeft()
            sleep(2)
        }
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
