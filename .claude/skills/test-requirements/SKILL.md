---
name: test-requirements
description: Turn a Journal feature or spec into a concrete test plan — acceptance criteria, the test matrix (unit/snapshot/UI/manual), edge cases, and privacy/safety cases that must be covered. Use when starting a feature, reviewing whether coverage is adequate, or defining "done".
---

# Test Requirements & Planning

Bridge from spec (`docs/product/`) to the concrete tests other skills implement. Produce a short, reviewable plan before writing code — not a bureaucratic document.

## Output shape
For a feature, produce:
1. **Acceptance criteria** — observable "given/when/then" statements that define done.
2. **Test matrix** — each criterion mapped to the cheapest layer that can verify it:
   | Layer | Skill | Use for |
   |---|---|---|
   | Unit (Swift Testing) | `swift-unit-tests` | logic: todo extraction, date/roll-forward, export round-trip, semantic-search ranking, migrations |
   | View/tree | `snapshot-testing` (ViewInspector) | component logic & rendering |
   | Snapshot | `snapshot-testing` | visual regression on design-system components |
   | UI E2E (XCUITest) | `xcuitest-writer` | critical multi-screen flows (compose→save→reopen, attach media, add todo w/ deadline) |
   | Agent validation | `ios-ui-automation` | exploratory "does it actually work/look right" |
   | Manual | — | things automation can't judge (haptics, motion feel, on-device AI quality) |
3. **Edge cases** — enumerate before coding.
4. **Privacy/safety cases** — mandatory for anything touching entries, export, AI, or sync (see below).

## Push tests down
Prefer the cheapest layer that gives confidence: logic → unit; a rendered card → snapshot; a whole flow → one UI test. Don't UI-test what a unit test can prove.

## Standing edge-case checklist for Journal
- **Entries:** empty, very long (Foundation Models 4096-token chunking), rich text + inline formatting, mixed media, no network, iCloud unavailable.
- **Media/attachments:** large video, unsupported/arbitrary file types, missing file (reference points at a deleted original), thumbnail generation failure.
- **Todos/deadlines:** past due, recurring, roll-forward of incomplete items across month/year/DST/time-zone; deletion cancels its notification.
- **Search/AI:** no results, on-device embedding for short vs long entries; cloud opt-in declined (must still work fully on-device).
- **Sync:** two devices editing the same entry (conflict), offline then reconnect, first-run empty store.

## Privacy & safety cases — NON-NEGOTIABLE
Any feature touching entries, export, AI, or sync MUST have tests for:
- **E2EE at rest:** persisted entry data is encrypted; keys never logged/persisted outside Secure Enclave/Keychain.
- **On-device vs cloud AI boundary:** with cloud AI *off*, no entry text leaves the device; with it *on*, only the exact user-selected text is sent — proven by asserting the outbound payload.
- **Export completeness & round-trip:** export → re-import reproduces entries, media references, todos, tags, and formatting with no loss; export is human-readable Markdown + media.
- **Data-loss / sync-conflict:** a schema change has a migration test seeded with the old store; a two-device conflict resolves without dropping content.
- **No data-safety paywall:** backup, export, and PIN/biometric lock are reachable on the free tier (a test/asserted config, not gated behind purchase).

These are the app's reason to exist — treat a gap here as release-blocking.

## Definition of done (per feature)
- [ ] Acceptance criteria all have a passing test at the right layer.
- [ ] Edge-case checklist reviewed; relevant ones covered.
- [ ] Privacy/safety cases covered (if entry/export/AI/sync-adjacent).
- [ ] `swift-bug-finder` checklist walked over the diff.
- [ ] Validated live once via `ios-ui-automation` (structure + screenshot, light & dark).
- [ ] Lint/format clean (`swift-lint-format`).
