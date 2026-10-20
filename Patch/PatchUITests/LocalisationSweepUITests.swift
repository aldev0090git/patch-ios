import XCTest

/// Walks the app in one language and photographs it, so a translation can be
/// judged where it actually lives rather than in the catalog.
///
/// `CLAUDE.md` records why this is worth the minutes: a translation can be
/// correct and still wrong. "Overall goal" became "Копить до суммы" — "save up
/// to a sum" — which made a feature that also covers 1000 km look like it was
/// only about money. And two segments of one picker both truncated to
/// "Определённы…", so it offered the same option twice. Neither is visible in
/// the catalog; both are obvious in a screenshot.
///
/// **Nothing here may name a translated string.** Everything is found by
/// accessibility identifier or by position, because every label this test
/// could ask for changes with the language. Set the language with
/// `TEST_RUNNER_PATCH_UI_LANGUAGE=ru` — `xcodebuild` forwards anything
/// prefixed `TEST_RUNNER_` to the runner, with the prefix stripped, and a
/// plain shell variable does not reach it because it runs on the simulator.
final class LocalisationSweepUITests: XCTestCase {
    private var language: String {
        ProcessInfo.processInfo.environment["PATCH_UI_LANGUAGE"] ?? "en"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSweepEveryScreen() throws {
        let app = XCUIApplication()
        app.launchArguments =
            ["-AppleLanguages", "(\(language))", "-AppleLocale", language]
            + ["-reset-state", "-demo-data"]
        app.launch()

        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 20), "No Today screen")
        shot(app, "01-today")

        // By position, not by name: the tab titles are translated.
        let tabs = app.tabBars.buttons
        XCTAssertEqual(tabs.count, 3, "Expected three tabs")
        for (index, name) in [(1, "02-calendar"), (2, "03-statistics")] {
            tabs.element(boundBy: index).tap()
            sleep(2)
            shot(app, name)
        }

        tabs.element(boundBy: 0).tap()
        sleep(1)

        // Settings: the densest list of prose in the app outside the editor.
        app.buttons["today.settings"].tap()
        XCTAssertTrue(
            app.switches["settings.reminders"].waitForExistence(timeout: 10),
            "No settings screen"
        )
        shot(app, "04-settings")
        app.swipeUp()
        sleep(1)
        shot(app, "05-settings-bottom")
        dismissSheet(app)

        // The editor, where a long translation overflows a row first.
        app.buttons["today.add"].tap()
        XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 10), "No goal editor")
        sleep(1)
        shot(app, "06-editor-top")

        // Scroll until the Apple Health section is on screen rather than
        // guessing at a number of swipes: it moved down the form when the
        // currency row appeared, and it will move again.
        let health = app.switches["editor.health"]
        for _ in 0..<4 where !health.exists || !health.isHittable {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(health.exists, "The Apple Health row never came into view")
        shot(app, "07-editor-health")

        app.swipeUp()
        sleep(1)
        shot(app, "08-editor-bottom")
    }

    /// By identifier, not by label: "Done" is "Готово" in the run this test
    /// exists for. A swipe-down was tried first and is not reliable — the
    /// sheet stayed up and the next tap landed on it instead of on Today.
    @MainActor
    private func dismissSheet(_ app: XCUIApplication) {
        let done = app.buttons["settings.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "No way to close the sheet")
        done.tap()
        XCTAssertTrue(
            app.buttons["today.add"].waitForExistence(timeout: 10),
            "The sheet did not close"
        )
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(language)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
