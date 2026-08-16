import XCTest

/// Stage 0 end-to-end launch test — proves the app boots on the simulator and
/// renders the placeholder root surface. Real golden-path flows (create entry →
/// mood → media → todo → search) arrive in Stage 14 via `xcuitest-writer`.
final class JournalLaunchUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesAndShowsPlaceholder() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()

        // The root placeholder is tagged with a stable accessibility identifier
        // so automation can find it regardless of copy changes.
        let root = app.otherElements["root.placeholder"]
        XCTAssertTrue(root.waitForExistence(timeout: 10), "Root placeholder should appear on launch")
        XCTAssertTrue(app.staticTexts["Journal"].exists, "App title should be visible")
    }
}
