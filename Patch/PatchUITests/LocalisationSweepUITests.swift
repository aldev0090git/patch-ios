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

        captureSettings(app)
        captureEditor(app)
        captureEditingTitle(app)
    }

    /// Settings and the how-it-works sheet behind it: the densest prose in the
    /// app outside the editor.
    @MainActor
    private func captureSettings(_ app: XCUIApplication) {
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

        // Almost entirely prose, and the one screen whose whole job is to
        // explain — so the one where a stiff translation shows most.
        app.buttons["settings.howItWorks"].tap()
        sleep(2)
        shot(app, "06-how-it-works")
        app.swipeUp()
        sleep(1)
        shot(app, "07-how-it-works-bottom")
        app.swipeDown(velocity: .fast)
        sleep(1)
        app.swipeDown(velocity: .fast)
        sleep(1)
        dismissSheet(app)
    }

    /// The goal editor, where a long translation overflows a row first.
    @MainActor
    private func captureEditor(_ app: XCUIApplication) {
        // The editor, where a long translation overflows a row first.
        app.buttons["today.add"].tap()
        XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 10), "No goal editor")
        sleep(1)
        shot(app, "08-editor-top")

        // Scroll until the Apple Health section is on screen rather than
        // guessing at a number of swipes: it moved down the form when the
        // currency row appeared, and it will move again.
        // Matched by identifier alone — the row is a menu picker now,
        // and this sweep cares where it is, not what kind of control it is.
        let health = app.descendants(matching: .any)
            .matching(identifier: "editor.health").firstMatch
        for _ in 0..<4 where !health.exists || !health.isHittable {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(health.exists, "The Apple Health row never came into view")
        shot(app, "09-editor-health")

        app.swipeUp()
        sleep(1)
        shot(app, "10-editor-bottom")

        app.buttons["editor.cancel"].tap()
        sleep(1)
    }

    /// The *editing* title, which is a different string from the new-goal one
    /// and twice as long in Russian — "Edit Goal" against "Редактировать
    /// цель" — in an inline navigation bar that already holds Cancel and Save.
    ///
    /// Reached by a full swipe right, which fires the leading action without
    /// needing to tap a translated menu item. A coordinate drag rather than
    /// `swipeRight()`: the gesture has to cross most of the row, and a short
    /// swipe on a short row has silently done nothing here before.
    @MainActor
    private func captureEditingTitle(_ app: XCUIApplication) {
        let row = app.cells.element(boundBy: 0)
        guard row.waitForExistence(timeout: 5) else {
            XCTFail("No goal row to edit")
            return
        }
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5))
            .press(
                forDuration: 0.1,
                thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
            )
        sleep(2)
        XCTAssertTrue(
            app.buttons["editor.save"].waitForExistence(timeout: 10),
            "A full swipe right did not open the editor"
        )
        shot(app, "11-editor-existing-title")
    }

    /// Onboarding is four pages of prose and the first thing anyone sees, so
    /// it is the worst place for an awkward translation. It only appears on a
    /// clean install, and demo data skips it, so it needs its own launch.
    @MainActor
    func testSweepOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments =
            ["-AppleLanguages", "(\(language))", "-AppleLocale", language] + ["-reset-state"]
        app.launch()

        let next = app.buttons["onboarding.primary"]
        XCTAssertTrue(next.waitForExistence(timeout: 20), "Onboarding did not appear")

        for page in ["01-welcome", "02-shapes", "03-choose", "04-how-it-works"] {
            shot(app, "onboarding-\(page)")
            next.tap()
            sleep(2)
        }

        // Finishing lands on Today with the goals onboarding created, whose
        // titles follow the phone's language rather than being frozen in at
        // creation — worth a picture of its own.
        XCTAssertTrue(
            app.buttons["today.add"].waitForExistence(timeout: 15),
            "Onboarding did not finish"
        )
        shot(app, "onboarding-05-seeded-goals")
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
