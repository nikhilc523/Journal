---
name: swift-unit-tests
description: Write and run unit/logic tests for the Journal app using Swift Testing (import Testing) — todo/deadline logic, recurrence, tag/search logic, on-device AI extraction, and SQLiteData models. Use when adding tests for non-UI logic or when a bug needs a regression test.
---

# Swift Unit Tests (Swift Testing)

Use **Swift Testing** (`import Testing`, built into Xcode 16+) for all new logic tests. Keep XCTest only for UI tests (`xcuitest-writer`). Both coexist in one target.

## Core API
```swift
import Testing
@testable import Journal

@Test func newEntryDefaultsToNow() {
    #expect(JournalEntry().createdAt.timeIntervalSinceNow < 1)   // prints operands on failure
}

@Test func loadsEntry() async throws {
    let e = try #require(await store.entry(id: seededID))        // unwrap-or-stop
    #expect(e.mood == .calm)
}

// runs once per argument, in parallel
@Test("valid attachment kinds", arguments: [MediaKind.photo, .video, .audio, .file])
func attachmentAccepted(_ k: MediaKind) { #expect(MediaAttachment.isSupported(k)) }

@Suite("Todo deadlines")
struct TodoTests {                              // fresh instance per test = isolation
    @Test func overdueRollsForward() {
        var t = Todo(title: "x", dueDate: .distantPast)
        t.rollForwardIfOverdue(now: .now)
        #expect(t.dueDate ?? .distantPast > .distantPast)
    }
}
```

## Traits
- `@Test(.disabled("reason"))`, `@Test(.timeLimit(.minutes(1)))`, `@Test(.tags(.integration))`.
- `@Suite(.serialized)` — opt out of parallelism when tests share one database connection.
- `@MainActor` on tests that touch main-actor state (most UI-model / store code).

## What to test in Journal (priority order)
Map to `docs/product/01-data-model.md`:
1. **Todo & deadline logic** — due-date scheduling, recurrence expansion, roll-forward of incomplete todos, and the Today/Upcoming/Done partitioning. Assert notification identifiers are stable so reschedules don't duplicate.
2. **Search & tagging** — semantic/keyword query returns the right entries; auto-tag extraction is deterministic on fixed input.
3. **On-device AI extraction** — entry→todo and auto-tag parsing map fixed sample text to the expected `@Generable` struct (test the parsing/mapping layer, not the model itself; stub the model output).
4. **Media/attachment model** — supported kinds, relative-path integrity, checksum, thumbnail-path derivation.
5. **SQLiteData models** — validation, defaults, relationships, and migrations (use an in-memory database).

## SQLiteData in tests — use an in-memory database
```swift
import GRDB

func makeInMemoryDB() throws -> DatabaseQueue {
    let dbQueue = try DatabaseQueue()            // in-memory; nothing touches disk or CloudKit
    try AppMigrator.shared.migrate(dbQueue)      // same migrator the app uses
    return dbQueue
}
```
Never point tests at the CloudKit-backed store. Run migrations through the *same* `DatabaseMigrator` the app ships so tests exercise the real schema path.

## Run
```bash
xcodebuild test -scheme Journal \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' \
  -only-testing:JournalTests \
  -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO
```
Read coverage: `xcrun xccov view --report TestResults.xcresult`.

## Guidance
- One behavior per `@Test`; name it after the behavior, not the method.
- Prefer parameterized tests over copy-pasted near-duplicates.
- When fixing a bug, first write the failing test that reproduces it, then fix (see `swift-bug-finder`).
