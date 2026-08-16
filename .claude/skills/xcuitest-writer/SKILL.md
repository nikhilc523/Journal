---
name: xcuitest-writer
description: Write end-to-end XCUITest UI tests for Journal key flows (create an entry, attach media, add a todo with a deadline, verify timeline/search). Use when adding automated UI regression coverage that runs in CI. For free-form interactive validation use ios-ui-automation instead.
---

# XCUITest Writer

UI automation is **XCTest-only** (Swift Testing doesn't cover it). Use this for checked-in, CI-run happy-path coverage of the flows that must never break. For exploratory/agent-driven validation, use `ios-ui-automation`.

## Deterministic test mode
The app must not talk to real CloudKit during UI tests. Gate on a launch argument:
```swift
// In JournalApp
if CommandLine.arguments.contains("-uiTesting") {
    // in-memory SQLiteData database, seed fixed fixtures, disable CloudKit sync
}
```

## Anatomy of a test
```swift
import XCTest

final class CreateEntryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testCreateEntryAppearsInTimeline() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()

        app.buttons["newEntryButton"].tap()
        app.textViews["entryComposerTextEditor"].typeText("Morning walk by the river")
        app.buttons["saveEntryButton"].tap()

        XCTAssertTrue(app.staticTexts["entryRow"].waitForExistence(timeout: 2))
    }
}
```

## Rules
- **Query by `accessibilityIdentifier`, never by visible text** (copy/localization/emoji break it). If a needed view lacks one, add it (see `accessibility-audit`).
- Always `waitForExistence(timeout:)` before asserting — the glass/spring animations mean elements appear async.
- `continueAfterFailure = false` so the first failure is the signal.
- Keep each test one flow; no shared mutable state between tests.

## Flows to cover for Journal
1. **Create an entry** → type text, pick a mood → entry appears in the timeline.
2. **Onboarding** → grant/skip permissions, land on the timeline.
3. **Attach media** → add a photo (seed a fixture asset in `-uiTesting`), assert the thumbnail renders in the entry.
4. **Todo with deadline** → add an inline todo with a due date → it appears in the "Today/Upcoming" task view and schedules a notification (assert via the in-process notification mock).
5. **Search** → create two entries, run a query, assert only the matching entry is listed.
6. **Persistence across relaunch** → create an entry, relaunch (with the persistent `-uiTestingPersistent` store), assert it survived.

## Run
```bash
xcodebuild test -scheme Journal \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' \
  -only-testing:JournalUITests CODE_SIGNING_ALLOWED=NO
```

## Guidance
- UI tests are slow and flakier than unit tests — cover *critical* flows only; push detailed assertions down to `swift-unit-tests`.
- Data-integrity flows (#4, #6) are the ones worth the UI-test cost — losing a user's entries or a scheduled reminder is the worst failure this app can have.
