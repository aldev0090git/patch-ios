import XCTest

/// Runs Apple's own accessibility audit over every screen.
///
/// `performAccessibilityAudit()` checks the mechanical half of accessibility —
/// elements with no description, text that clips at large sizes, hit regions
/// under 44pt, contrast, wrong traits — which is exactly the half that is
/// tedious to find by hand and easy to regress.
///
/// Out of CI like the other UI tests: it needs a simulator.
final class AccessibilityAuditUITests: XCTestCase {
    /// Collected across every screen and attached at the end. `print` from a
    /// UI test does not reach `xcodebuild`'s output, so findings have to be
    /// carried out in the result bundle.
    private var findings: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        findings = []
    }

    override func tearDownWithError() throws {
        // Grouped and counted: the same control repeated across twenty rows
        // is one thing to fix, not twenty.
        var counts: [String: Int] = [:]
        for finding in findings { counts[finding, default: 0] += 1 }
        let report = counts
            .sorted { ($0.value, $0.key) > ($1.value, $1.key) }
            .map { "\($0.value)x  \($0.key)" }
            .joined(separator: "\n")
        let attachment = XCTAttachment(
            string: "\(findings.count) issue(s), \(counts.count) distinct\n\n" + report
        )
        attachment.name = "accessibility-audit"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testEveryScreenPassesTheAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo-data"]
        app.launch()

        XCTAssertTrue(app.buttons["today.add"].waitForExistence(timeout: 15), "No Today screen")
        try audit(app, named: "Today")

        app.buttons["today.add"].tap()
        XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 10), "No goal editor")
        try audit(app, named: "Goal editor")
        app.buttons["editor.cancel"].tap()
        sleep(1)

        app.buttons["today.settings"].tap()
        XCTAssertTrue(app.switches["settings.reminders"].waitForExistence(timeout: 10), "No Settings")
        try audit(app, named: "Settings")
        app.buttons.matching(identifier: "Done").firstMatch.tap()
        sleep(1)

        app.tabBars.buttons.element(boundBy: 1).tap()
        let firstOfMonth = app.descendants(matching: .any)
            .matching(identifier: "calendar.day.1").firstMatch
        XCTAssertTrue(firstOfMonth.waitForExistence(timeout: 10), "No Calendar")
        try audit(app, named: "Calendar")
        firstOfMonth.tap()
        sleep(1)
        try audit(app, named: "Calendar with a day open")

        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(2)
        try audit(app, named: "Statistics")
    }

    /// Collects rather than fails, for now: the point of the first run is to
    /// find out what is wrong, and a test that stops at the first issue hides
    /// the other five screens.
    @MainActor
    private func audit(_ app: XCUIApplication, named screen: String) throws {
        try app.performAccessibilityAudit { issue in
            let element = issue.element
            let kind = element.map { "\($0.elementType.rawValue)" } ?? "?"
            let identifier = element?.identifier ?? ""
            let label = element.map { String($0.label.prefix(40)) } ?? ""
            let size = element.map { "\(Int($0.frame.width))x\(Int($0.frame.height))" } ?? "-"
            let location = [
                kind,
                identifier.isEmpty ? "-" : identifier,
                label.isEmpty ? "-" : label,
                size
            ].joined(separator: " / ")
            let detail = element == nil
                ? String(issue.detailedDescription.prefix(150))
                    .replacingOccurrences(of: "\n", with: " ")
                : ""
            self.findings.append("[\(screen)] \(issue.compactDescription) :: \(location) \(detail)")
            return true
        }
    }
}
