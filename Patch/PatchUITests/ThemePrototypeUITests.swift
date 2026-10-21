import XCTest

/// Photographs each page theme on the three screens that wear it.
///
/// A prototype aid, not an assertion of anything: it exists so the themes can
/// be judged from screenshots rather than from a description of them.
///
/// **Skipped in the shared scheme.** Ten captures is minutes of a run that
/// asserts almost nothing, so it is off by default and invoked by name:
/// `-only-testing:PatchUITests/ThemePrototypeUITests`. What it is for is
/// covered by `ThemedInteractionUITests`, which does assert, and runs. Same
/// launch-argument route as `ScreenshotUITests` — `-pageTheme gold` drives
/// the app's real stored setting, so what is photographed is what a user
/// would get. `-demo-data` goes last; it is a bare flag, and `UserDefaults`
/// would otherwise eat the key after it.
final class ThemePrototypeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testGold() { capture("gold") }
    @MainActor func testRoseGold() { capture("roseGold") }
    @MainActor func testPlatinum() { capture("platinum") }
    @MainActor func testPlain() { capture("plain") }
    @MainActor func testPaper() { capture("paper") }

    @MainActor func testGoldDark() { capture("gold", appearance: "dark") }
    @MainActor func testRoseGoldDark() { capture("roseGold", appearance: "dark") }
    @MainActor func testPlatinumDark() { capture("platinum", appearance: "dark") }
    @MainActor func testPlainDark() { capture("plain", appearance: "dark") }
    @MainActor func testPaperDark() { capture("paper", appearance: "dark") }

    @MainActor
    private func capture(_ theme: String, appearance: String = "light") {
        let name = appearance == "dark" ? "\(theme)-dark" : theme
        let app = XCUIApplication()
        app.launchArguments = [
            "-appearance", appearance, "-accentTheme", "blue", "-pageTheme", theme,
            "-reset-state", "-demo-data"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 20), "No Today screen")
        sleep(1)
        attach(app.screenshot(), named: "\(name)-1-today")

        // Scrolled, not only at rest. The pinned header is the one place
        // content passes behind something, so it is the one place a
        // transparent background would show.
        app.swipeUp()
        sleep(1)
        attach(app.screenshot(), named: "\(name)-1b-today-scrolled")
        app.swipeDown()
        sleep(1)

        // By position: the tab titles translate, and this may be run in any
        // language to check a wash against a longer word.
        let tabs = app.tabBars.buttons
        for (index, screen) in [(1, "2-calendar"), (2, "3-statistics")] {
            tabs.element(boundBy: index).tap()
            sleep(2)
            attach(app.screenshot(), named: "\(name)-\(screen)")
        }

        tabs.element(boundBy: 0).tap()
        sleep(1)
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(
            app.buttons["theme.\(theme)"].waitForExistence(timeout: 10),
            "Settings has no swatch for \(theme)"
        )
        // Proof the launch argument reached the real setting rather than only
        // the chrome: the swatch for this theme is the selected one.
        XCTAssertTrue(
            app.buttons["theme.\(theme)"].isSelected,
            "Settings does not show the theme the app launched with"
        )
        sleep(1)
        attach(app.screenshot(), named: "\(name)-4-settings")
    }

    @MainActor
    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
