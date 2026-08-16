import XCTest

/// Stage 4 end-to-end: the create → write → autosave → timeline loop through the
/// real UI (native rich-text editor + hero presentation). Runs on the in-memory
/// `-uiTesting` store, so it's deterministic and never touches disk or iCloud.
///
/// Note: the floating glass chrome (FAB, tab bar) currently reports the ancestor
/// `timeline.root` identifier rather than its own, so we locate controls by their
/// stable VoiceOver labels here. (Tightening those identifiers is an
/// accessibility-audit follow-up.)
final class EntryComposerUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testCreateEntryWritesRichTextAndPersistsToTimeline() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()

        XCTAssertTrue(app.otherElements["timeline.root"].waitForExistence(timeout: 15), "Timeline should appear")

        // Open the composer from the FAB (located by its accessibility label).
        let fab = app.buttons["New entry"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "FAB should be present")
        fab.tap()

        // The composer surface appears (hero from the card).
        XCTAssertTrue(app.otherElements["composer.root"].waitForExistence(timeout: 10), "Composer should open")

        // Write into the native rich-text editor.
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "Editor should be present")
        editor.tap()
        editor.typeText("Launched the side hustle today")

        // Close — this flushes the autosave.
        app.buttons["Done"].tap()

        // Back on the timeline, the entry persisted and previews the written text.
        let saved = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "side hustle"))
            .firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 10), "Saved entry should appear on the timeline")
    }
}
