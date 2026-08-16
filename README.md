# Journal

A calm, local-first iOS journal — each day is one surface for writing, media, files, and **todos with deadlines**. Private by default, on-device AI, human-readable export.

> iOS 26 · native SwiftUI · SQLiteData (GRDB) + CloudKit · on-device AI · opt-in Claude cloud AI

## Status

**Stage 0 — scaffold.** Buildable, test-backed, CI-enforced skeleton. Feature work follows the 15-stage build plan (kept in local planning docs).

## Getting started

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate          # regenerate Journal.xcodeproj from project.yml
open Journal.xcodeproj
```

Build & test from the command line (matches CI):

```bash
xcodebuild test \
  -project Journal.xcodeproj -scheme Journal \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' \
  CODE_SIGNING_ALLOWED=NO
```

`Journal.xcodeproj` is generated and **git-ignored** — always run `xcodegen generate` after cloning or editing `project.yml`.

## Layout

| Path | Purpose |
|---|---|
| `project.yml` | XcodeGen project definition (targets, deps, scheme) |
| `Journal/Sources` | App code |
| `Journal/Resources` | Assets (app icon, accent color) |
| `JournalTests` | Unit tests (Swift Testing) |
| `JournalSnapshotTests` | Snapshot / view-tree tests (SnapshotTesting + ViewInspector) |
| `JournalUITests` | End-to-end XCUITests |
| `.github/workflows` | CI (`ci.yml` build+test+coverage) and per-PR `stage-review.yml` |
| `.claude/skills` | Project-specific Claude Code skills |

## Contributing

`main` is branch-protected: branch → green local tests → PR → **green "Build & Test" CI** → squash-merge. See `CLAUDE.md` for the full gate and privacy invariants.
