import XCTest

/// End-to-end launch test — proves the app boots on the simulator and renders
/// the Timeline home screen. Real golden-path flows (create entry → mood →
/// media → todo → search) arrive in Stage 14 via `xcuitest-writer`.
final class SedimentLaunchUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesAndShowsTimeline() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()

        // The Timeline root is tagged with a stable accessibility identifier so
        // automation can find it regardless of copy changes.
        let root = app.otherElements["timeline.root"]
        XCTAssertTrue(root.waitForExistence(timeout: 10), "Timeline should appear on launch")
    }
}
