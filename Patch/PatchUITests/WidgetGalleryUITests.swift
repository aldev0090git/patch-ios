import XCTest

/// Adds the widget to the home screen and photographs it.
///
/// Run by hand, never in CI: it drives SpringBoard and depends on the home
/// screen's own layout, which changes between iOS versions.
///
/// Finds Patch by searching the gallery rather than scrolling to it. The
/// list is built lazily and ordered differently on each runtime, and an
/// earlier version of this test read "I scrolled and did not see it" as
/// "iOS 26 has no widget gallery", which is not true — Patch appears there
/// perfectly well.
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

        // The gallery's own search field, rather than swiping and hoping.
        // The list is long and built lazily, so an app near the bottom is
        // simply not in the tree yet; the earlier version swiped past Patch
        // and concluded the runtime was at fault.
        let search = springboard.searchFields.firstMatch
        if search.waitForExistence(timeout: 10) {
            search.tap()
            search.typeText("Patch")
            sleep(3)
        }

        let patch = springboard.staticTexts["Patch"].firstMatch
        guard patch.waitForExistence(timeout: 10) else {
            attach(named: "gallery-without-patch")
            XCTFail("Patch was not in the widget gallery")
            return
        }
        // By coordinate: the label is inside a gallery cell and reports
        // itself as not hittable, though the row it sits in takes the tap.
        patch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
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
