import XCTest

/// Adds the widget to the home screen and photographs it.
///
/// **Needs an iOS 27 runtime.** On 26.5 the gallery is empty — of everything,
/// including Apple's own widgets — so this fails there for reasons that have
/// nothing to do with Patch. See the widget note in `CLAUDE.md`.
///
/// Run by hand, never in CI: it drives SpringBoard and depends on the home
/// screen's own layout.
final class WidgetGalleryUITests: XCTestCase {
    @MainActor
    private var springboard: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testAddTheWidget() throws {
        // Launch once so the app writes its snapshot, then get out of the way.
        let app = XCUIApplication()
        app.launchArguments = ["-reset-state", "-demo-data"]
        app.launch()
        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 20), "No Today screen")
        sleep(2)
        app.terminate()

        springboard.activate()
        sleep(3)

        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
            .press(forDuration: 1.6)
        sleep(3)

        // Two taps: "Edit" only opens a menu, and the gallery is behind an
        // "Add Widget" item inside it.
        if springboard.buttons["Edit"].waitForExistence(timeout: 5) {
            springboard.buttons["Edit"].tap()
            sleep(2)
        }
        let addWidget = springboard.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'widget'")
        ).firstMatch
        if addWidget.waitForExistence(timeout: 5) {
            addWidget.tap()
        }
        sleep(5)

        let patch = springboard.staticTexts["Patch"].firstMatch
        for _ in 0..<6 where !patch.exists {
            springboard.swipeUp()
            sleep(1)
        }
        guard patch.waitForExistence(timeout: 5) else {
            attach(named: "gallery-without-patch")
            XCTFail("Patch was not in the widget gallery — is this an iOS 26 runtime?")
            return
        }
        patch.tap()
        sleep(3)
        attach(named: "1-small")

        springboard.swipeLeft()
        sleep(2)
        attach(named: "2-medium")

    }

    @MainActor
    private func attach(named name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
