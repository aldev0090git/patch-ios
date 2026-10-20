import XCTest

/// Proves the reordering gesture, which is the part of the feature that
/// cannot be settled by reading documentation.
///
/// `List`'s `.onMove` is usually described as needing edit mode. Whether a
/// plain long-press-and-drag reorders without it — and whether that fights
/// the context menu already on the same long press — is a question about the
/// running app.
final class ReorderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testReorderingFromTheContextMenu() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-state", "-demo-data"]
        app.launch()

        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 20), "No Today screen")
        let before = titles(app)
        XCTAssertGreaterThan(before.count, 1, "Need at least two goals to reorder")
        attach(app.screenshot(), named: "1-before")

        app.cells.element(boundBy: 0).press(forDuration: 1.2)
        sleep(2)
        let reorder = app.buttons["Reorder"]
        XCTAssertTrue(reorder.waitForExistence(timeout: 5), "No Reorder item in the menu")
        reorder.tap()
        sleep(2)
        attach(app.screenshot(), named: "2-edit-mode")

        XCTAssertTrue(
            app.buttons["today.doneReordering"].waitForExistence(timeout: 5),
            "Edit mode did not start"
        )

        // The drag handle, not the card: in edit mode the row's content is
        // inert and only the handle moves it.
        let handles = app.buttons.matching(identifier: "Reorder").allElementsBoundByIndex
        let grip = handles.last ?? app.cells.element(boundBy: 0)
        grip.press(
            forDuration: 0.6,
            thenDragTo: app.cells.element(boundBy: 1),
            withVelocity: .slow,
            thenHoldForDuration: 0.8
        )
        sleep(2)
        attach(app.screenshot(), named: "3-after-drag")

        let after = titles(app)
        XCTAssertNotEqual(before, after, "The drag did not reorder. before=\(before)")
    }

    /// Goal titles in list order. The cells themselves have no label — an
    /// earlier version of this test compared ["", ""] with ["", ""] and
    /// passed judgement on it.
    @MainActor
    private func titles(_ app: XCUIApplication) -> [String] {
        ["Read", "Water", "Push-ups", "Coffee", "Steps", "Gym", "Save"]
            .compactMap { name -> (Int, String)? in
                let element = app.staticTexts[name]
                guard element.exists else { return nil }
                return (Int(element.frame.minY), name)
            }
            .sorted { $0.0 < $1.0 }
            .map(\.1)
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
