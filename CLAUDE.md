# Journal — Repository Gate (CLAUDE.md)

Calm, local-first iOS journal: each day is one surface for writing + media + files + **todos-with-deadlines**. Private by default, on-device AI, human-readable export. This file is the always-on gate — its rules **override** default behavior.

## Platform (locked — do not revisit)
- **iOS 26 only**, native SwiftUI, **iOS-only**. No Android, no back-deployment shims.
- Scheme **`Journal`**. Simulator: **iPhone 17 / OS=26.0**.
- Swift 6 language mode; respect strict concurrency (`ModelContext`/GRDB queues, `@MainActor` UI).

## Source of truth
- `docs/` is the SOT (product, data model, design, decisions). **Never invent design tokens** — read `docs/design/design-tokens.md`.
- Locked decisions live in `docs/decisions/0001-foundational-decisions.md`. The staged build is in `master-plan.md`; each stage's contract is in `docs/product/02-build-plan.md`.
- Note: `docs/`, `UI_Interface/`, `master-plan.md`, `PLAN.md` are **git-ignored** (local planning material, kept out of the remote). Handoffs live under `docs/handoff/`.

## Privacy invariants (P0 — a violation blocks any merge)
1. No readable entry text leaves the device without **explicit, per-entry opt-in**; a cloud AI call sends only the user-selected text.
2. Entries are **E2EE at rest**; keys stay in Secure Enclave / iCloud Keychain — never logged or persisted elsewhere.
3. Export is **human-readable** (Markdown + media) and leaves no plaintext behind in temp/caches/logs.
4. Media `relativePath` is validated before use — no path traversal / sandbox escape.
5. **Never paywall data safety** (backup, export, PIN).
6. Cloud AI provider is **Anthropic Claude** (`claude-opus-4-8` default, `claude-haiku-4-5` cheap). **Never `claude-fable-5`** (retention/ZDR unfit for journal data). API key is never bundled or committed.

## Persistence (locked)
- **SQLiteData** (Point-Free, on GRDB) + CloudKit `SyncEngine` for private sync (sharing deferred).
- **Media on the filesystem**, referenced from the DB (`relativePath`/`UTType`/`checksum`) — never blobs in the DB.
- Every schema change ships an explicit `DatabaseMigrator` migration **and** a test seeded with the old schema. No migration = data loss = BLOCK.

## Engineering rules
- **Never force-unwrap** runtime values (`!`/`try!`/`as!`) from CloudKit/GRDB/file/JSON. Crashes block merges.
- Every interactive view gets a stable `accessibilityIdentifier` (also enables UI automation).
- Test at the cheapest layer that proves it: unit (Swift Testing) → snapshot (pinned to iPhone 17/26.0) → XCUITest. New behavior ships with a regression test.
- Thumbnailing / heavy work off the main thread.

## Definition of done (every stage)
1. `xcodegen generate` + `xcodebuild test` (iPhone 17 / OS=26.0) **fully green** locally.
2. New behavior has a test; no test weakened/disabled to pass.
3. Privacy invariants held; no secrets or generated files staged.
4. `/stage-review` clean (BLOCK/WARN/PASS), then `/github-push`.

## The push gate (mandatory)
`main` is branch-protected. Branch → local tests green → PR → **green CI ("Build & Test")** → squash-merge → delete branch. Full checklist in the **`github-push`** skill. Never push to `main` directly; never merge on red CI.

## Skills (`.claude/skills/`)
Feature loop: `test-requirements` → `swiftui-developer` / `persistence-setup` → `swift-unit-tests` / `snapshot-testing` / `xcuitest-writer` → `ios-build-run` → `ios-ui-automation` → `swift-bug-finder` / `swift-lint-format` / `accessibility-audit` → `ios-release-validator`, with `stage-review` + `github-push` gating every stage.
