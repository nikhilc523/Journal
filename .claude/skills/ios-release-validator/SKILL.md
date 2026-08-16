---
name: ios-release-validator
description: Pre-ship validation gate for Journal — runs the full test suite, checks entitlements/privacy strings, CloudKit/WeatherKit/notification requirements, App Store rules, and the privacy invariants (E2EE, export, no server-readable entries). Use before a TestFlight build, a release, or when asked "is this ready to ship?".
---

# iOS Release Validator

The go/no-go checklist before any build leaves the machine. Anything unchecked in **Privacy & Safety** is release-blocking.

## 1. Build & tests green
```bash
xcodebuild test -scheme Journal \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' \
  -enableCodeCoverage YES -resultBundlePath TestResults.xcresult CODE_SIGNING_ALLOWED=NO
xcrun xccov view --report TestResults.xcresult      # coverage sanity
```
- Unit (`swift-unit-tests`), snapshot (`snapshot-testing`), and critical UI flows (`xcuitest-writer`) all pass.
- `swift-bug-finder` checklist walked over the release diff; `swift-lint-format` clean.

## 2. Live smoke via automation
Use `ios-ui-automation` to run the key flows on a clean simulator (`simctl erase`), light **and** dark:
- compose entry → add photo/voice/file → save → reopen · add a todo with a deadline · export → confirm human-readable output · semantic search returns a result · mood picker (Fluent 3D emoji) selects.

## 3. Entitlements & Info.plist
- iCloud/CloudKit entitlement; container configured for SQLiteData `SyncEngine`.
- WeatherKit entitlement; usage honest; Apple Weather attribution present.
- Location (`NSLocationWhenInUseUsageDescription`), Photos, Microphone (`NSMicrophoneUsageDescription`), Speech, and (if used) Reminders/Calendar usage strings — all written for a human, not boilerplate.
- Notification authorization requested at a sensible moment; `.timeSensitive` entitlement only if used.

## 4. Apple review gates
- **No medical/therapy claims** anywhere in UI/metadata. AI is a "reflection companion," never an "AI therapist"; if a reflection/chat feature ships, a "not a doctor / this is AI" disclaimer is visible and crisis-escalation guidance is present.
- App Privacy "nutrition label" in App Store Connect **matches actual data flows** — since entries are local/E2EE, declare accordingly; declare the optional Claude API path honestly (only opted-in text, not used for training).
- No data selling; no third-party sharing without consent.
- Mandatory privacy policy linked.

## 5. Privacy & safety invariants (BLOCKING)
- [ ] Entries are E2EE at rest; keys self-custodied (Secure Enclave/Keychain), never logged/persisted elsewhere.
- [ ] With cloud AI off, **no entry text leaves the device**. With it on, only the exact user-selected text is sent (verified on the outbound payload).
- [ ] Export produces complete, human-readable Markdown + media and round-trips on re-import; no plaintext left in temp/caches/logs afterward.
- [ ] No server stores readable entries; sync payloads are the user's own private CloudKit data.
- [ ] Data-safety features (backup, export, PIN/biometric lock) are **not paywalled**.
- [ ] Any schema change since last release has a tested migration (no data loss on update).

## 6. Ecosystem & polish
- iCloud sync across two devices; offline behavior graceful; a two-device edit conflict resolves without data loss.
- Deadline notifications fire; completing/deleting a todo cancels its notification.
- Widgets/Lock Screen (if shipped) render.
- Dynamic Type XXL + increased contrast + Reduce Motion all usable (`accessibility-audit`).

## Output
Produce a short go/no-go with each section pass/fail and every failure as a concrete blocker. **Never green-light with an open Privacy & Safety item.**
