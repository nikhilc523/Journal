---
name: swift-bug-finder
description: Hunt correctness and crash bugs in Journal's Swift/SwiftUI code — force-unwraps, retain cycles, Swift 6 concurrency/data races, SQLiteData/GRDB + CloudKit pitfalls, privacy leaks (entry text off-device, unencrypted export, over-scoped cloud AI), media path traversal, notification/EventKit misuse. Use when reviewing a diff for bugs, triaging a crash, or before merging risky code.
---

# Swift Bug Finder

Static + tool-assisted bug hunting tuned to *this* app's failure modes. When you find a real bug, write a failing test (`swift-unit-tests`) before fixing.

## Tools
```bash
xcodebuild analyze -scheme Journal -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0'  # Apple static analyzer
swiftlint analyze          # semantic lint (force-unwrap, unused, etc.)
periphery scan             # dead code that hides bugs
```
Turn on **Swift 6 strict concurrency** (`SWIFT_STRICT_CONCURRENCY = complete`) — the compiler then flags most data races for you.

## Bug classes to check (in priority for Journal)

### 1. Privacy leaks (highest severity — P0)
This app's promise is local-first + E2EE. Any of these is a P0:
- **Readable entry text reaching a server without explicit opt-in.** Grep for network calls (`URLSession`, the Claude client) and prove the payload is (a) user-initiated for *this* entry and (b) only the text the user chose to send — not the whole entry, not neighbors, not metadata beyond what was opted into.
- **Cloud AI over-scoping.** A summary/reflection call that decrypts and ships more than the selected text (e.g. the entire journal, or attachments) → leak.
- **Unencrypted export path exposure.** Export must be an explicit user action to a user-chosen destination; no plaintext written to a shared/temp/iCloud location that outlives the export, no plaintext left in caches/logs.
- **Plaintext at rest.** Any entry field persisted un-encrypted, or a key logged/persisted outside Secure Enclave/Keychain.
- **Media/attachment path traversal.** A `relativePath` from import/sync joined to a base dir without validation → escaping the sandbox container. Resolve + verify the path stays under the media root.

### 2. Crash-prone unwrapping
- `!`, `try!`, `as!` on anything not provably non-nil. Grep the diff for `!` and justify each.
- Force-unwrapped optionals from CloudKit/GRDB rows/JSON/file reads — these are *runtime* values, never force.

### 3. Retain cycles / leaks
- Escaping closures, `Task { }`, Combine `sink`, delegate patterns capturing `self` strongly → require `[weak self]` (then `guard let self`).
- SwiftUI: a view model holding a closure back to the view; long-lived `AVAudioPlayer`/`AVPlayer` retained across re-renders.

### 4. Concurrency / data races (Swift 6)
- GRDB database access off the intended queue; UI state mutated from a background continuation without hopping to `@MainActor`.
- Shared mutable singletons without actor isolation.
- Media/thumbnail generation blocking the main thread (`AVAssetImageGenerator` is slow — must be off-main).

### 5. SQLiteData / GRDB + CloudKit pitfalls
- **Migration integrity:** every schema change is an explicit, ordered `DatabaseMigrator` migration; renames/type changes have a data-preserving migration + a test seeded with the old schema. A schema change with no migration → data loss on update. P0.
- SQLiteData `SyncEngine`: large binaries handled as CloudKit assets (background), not inline; conflict policy (per-field last-write-wins) understood for the changed table.
- Never delete/rewrite the store to "fix" a migration.

### 6. Notifications / EventKit misuse
- Deadline reminders scheduled without checking/So requesting authorization; orphaned notifications when a todo is deleted/completed (must cancel by identifier).
- EventKit: request access lazily at first "Add to Reminders"; treat it as a one-way mirror — don't two-way sync and don't make Reminders the source of truth.
- Roll-forward logic for incomplete todos: off-by-one on dates, DST, time-zone changes.

### 7. Domain-logic bugs
- On-device AI extraction (entry→todos) producing wrong due dates from relative phrasing ("next Friday") across week/month/DST boundaries.
- Foundation Models 4096-token context overflow not handled (long entries must chunk) → silent truncation or `exceededContextWindowSize`.
- Export/import round-trip losing data (media references, todos, tags, formatting).

## Procedure
1. Read the diff (or `git diff`), not the whole repo.
2. Run the analyzer + `swiftlint analyze` and read their hits.
3. Walk the checklist above against the changed code; for each suspected bug state the concrete failing scenario.
4. Rank by severity — **privacy leaks and crashes first**.
5. For each confirmed bug: a failing test, then the fix. Report what you found, the repro, and the fix.
