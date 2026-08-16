# Sediment

A calm, local-first iOS journal — each day is one surface for writing, media, files, and **todos with deadlines**. Private by default, on-device AI, human-readable export.

> iOS 26 · native SwiftUI · SQLiteData (GRDB) + CloudKit · on-device AI · opt-in Claude cloud AI

## Status

**Stages 0–3 landed.** Buildable, test-backed, CI-enforced skeleton with the design system, the data layer (SQLiteData + CloudKit), and the Timeline home screen. Feature work follows the 15-stage build plan (kept in local planning docs).

## Getting started

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate          # regenerate Sediment.xcodeproj from project.yml
open Sediment.xcodeproj
```

Build & test from the command line (matches CI):

```bash
xcodebuild test \
  -project Sediment.xcodeproj -scheme Sediment \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -skipMacroValidation -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO
```

`Sediment.xcodeproj` is generated and **git-ignored** — always run `xcodegen generate` after cloning or editing `project.yml`.

## Layout

| Path | Purpose |
|---|---|
| `project.yml` | XcodeGen project definition (targets, deps, scheme) |
| `Sediment/Sources` | App code (design system, data layer, features) |
| `Sediment/Resources` | Assets (app icon, accent color) |
| `SedimentTests` | Unit tests (Swift Testing) |
| `SedimentSnapshotTests` | Snapshot / view-tree tests (SnapshotTesting + ViewInspector) |
| `SedimentUITests` | End-to-end XCUITests |
| `.github/workflows` | CI (`ci.yml` build+test+coverage) and per-PR `stage-review.yml` |
| `.claude/skills` | Project-specific Claude Code skills |

## Contributing

`main` is branch-protected: branch → green local tests → PR → **green "Build & Test" CI** → squash-merge. See `CLAUDE.md` for the full gate and privacy invariants.
