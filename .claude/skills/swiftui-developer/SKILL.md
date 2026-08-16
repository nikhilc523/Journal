---
name: swiftui-developer
description: Build features in the Journal SwiftUI app following its architecture and design-system conventions — SQLiteData models, on-device AI by default, media/attachment handling, todos-in-entry, E2EE boundaries, and the reusable component conventions. Use when implementing or modifying app features/UI.
---

# SwiftUI Developer (Journal conventions)

How to add code to Journal so it matches the architecture in `docs/product/` and the design language in `docs/design/`. Read those first for anything non-trivial. Target is **iOS 26 only, native SwiftUI, iOS-only** — use native APIs directly, no back-deployment fallbacks.

## Architecture guardrails
- **Local-first, single owner.** All entries live on-device in **SQLiteData (GRDB)**; CloudKit via SQLiteData's `SyncEngine` is the user's *own* private sync + optional iCloud sharing. There is no server that reads entries.
- **Encrypted at rest.** Entries are zero-knowledge E2EE with self-custody keys (Secure Enclave / iCloud Keychain). No plaintext entry ever leaves the device unencrypted.
- **On-device AI by default.** Semantic search (`NLContextualEmbedding`), sentiment (`NLTagger`), entry→todo extraction and summaries (Foundation Models), transcription (`SpeechAnalyzer`), OCR (Vision) all run locally. The Claude API is used **only** on explicit, per-entry opt-in, decrypting *only* the specific text the user chose to send. Never send more than that.
- **Media on the filesystem, references in the DB.** Store originals in app storage; persist `relativePath + UTType + checksum + createdAt` rows. Never store blobs in the DB. Thumbnails generated lazily (`QLThumbnailGenerator` / `AVAssetImageGenerator`), off-main, cached.
- **Todos live inside entries.** A `Todo` may belong to a `JournalEntry`; deadlines are backed by `UNCalendarNotificationTrigger`; "Add to Apple Reminders" is an opt-in EventKit mirror, never the source of truth.
- **Data safety is never paywalled.** Backup, export (human-readable Markdown + media), and PIN/biometric lock are always available.

## Design system (build once, reuse)
**Visual design is TBD in the design phase (`docs/design/`).** Keep the *structure* now; fill in real values when design lands.
- Token groups: `Palette`, `Radius`, `Typography`, `Motion`, `Shadow`, `Haptics` — one source of truth, no ad-hoc literals in views.
- A material/glass surface component (`GlassCard` view + panel modifier) using iOS 26 `.glassEffect()` / `GlassEffectContainer`, with a `.regularMaterial` variant for dense text.
- Reusable pieces to expect: entry composer, entry card, media gallery, attachment row, todo/checkbox row, mood picker (Fluent 3D emoji), calendar/timeline, tag chip.
- Placeholder tokens until design: radius `sm/md/lg/pill` (always `.continuous`); a soft shadow token; a calm spring for motion. **Do not hard-code colors in views — reference `Palette` even while its values are provisional.**

## SwiftUI conventions
- `@Observable` model types (Observation framework), `@State` for view-owned state, `@Environment` for shared services.
- Text styles for Dynamic Type, never fixed sizes. **Never put body/data text directly on glass** — solid/high-opacity fill behind text (contrast; see `accessibility-audit`).
- Calm motion; respect `@Environment(\.accessibilityReduceMotion)`. Use Pow for change effects and Vortex for occasional celebration particles — sparingly, never nagging.
- Haptics on key interactions (soft on tap, success on save).
- **Every interactive/asserted view sets `.accessibilityIdentifier`** (see `accessibility-audit`, `ios-ui-automation`) — non-optional for testability.
- Progressive disclosure: keep the compose surface friction-free; detail/insights live at depth.

## Definition of done for a feature
1. Follows the architecture guardrails above (local-first, E2EE, on-device-AI-default, media-on-FS).
2. Uses design-system components/tokens, not ad-hoc styling.
3. Has accessibility identifiers + labels.
4. Tests planned via `test-requirements`, implemented via `swift-unit-tests` / `snapshot-testing` / `xcuitest-writer`.
5. Validated live with `ios-ui-automation` (light + dark), bug-checked with `swift-bug-finder`, lint-clean via `swift-lint-format`.
