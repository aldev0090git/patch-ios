import XCTest

/// Taking your data away, through the real screen.
///
/// The encoding is covered by fast domain tests; this covers what they
/// cannot — that the controls exist, that they are reachable, and that
/// tapping one actually opens the system share sheet with a file in it.
final class ExportUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testExportOffersAFileToShare() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-state", "-demo-data"]
        app.launch()

        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 15), "No Today screen")
        app.buttons["today.settings"].tap()

        // Both scrolled to, not assumed on screen. A List does not build
        // the rows below the fold, so an off-screen row is simply absent —
        // and Settings keeps growing, so anything near the bottom of it
        // will eventually slide under. Last time this test was fixed only
        // the CSV row was made to scroll; the next section added pushed the
        // JSON row under too.
        let export = scrollTo("settings.exportJSON", in: app)
        XCTAssertTrue(export.exists, "No way to export your data")

        // The CSV route is a separate control, not a mode of the first one.
        XCTAssertTrue(scrollTo("settings.exportCSV", in: app).exists, "No spreadsheet export")

        export.tap()

        // The share sheet is the system's, so the proof it opened with a real
        // file is that it offers somewhere to put one.
        let sheet = app.otherElements["ActivityListView"]
        let saveToFiles = app.buttons["Save to Files"]
        XCTAssertTrue(
            sheet.waitForExistence(timeout: 10) || saveToFiles.waitForExistence(timeout: 5),
            "Exporting did not open a share sheet"
        )
        attach(app.screenshot(), named: "export-share-sheet")
    }

    /// The element with this identifier, scrolled into existence.
    @MainActor
    @discardableResult
    private func scrollTo(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let element = app.descendants(matching: .any)
            .matching(identifier: identifier).firstMatch
        guard !element.waitForExistence(timeout: 5) else { return element }
        for _ in 0..<6 where !element.exists {
            app.swipeUp()
        }
        return element
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
