# Journal — iOS Delivery Skills

Project-scoped Claude Code skills that let an AI agent **develop, test, bug-hunt, and validate the running app through its real UI**. Each lives in its own folder as `SKILL.md` and is auto-discovered by Claude Code. Grounded in current tooling (Aug 2026, Xcode 26 / Swift 6, iOS 26 only) — see `docs/` for the product research these encode.

## The skills

| Skill | What it does |
|---|---|
| **swiftui-developer** | Build features to Journal's architecture + design system |
| **persistence-setup** | Set up SQLiteData (on GRDB) + CloudKit SyncEngine; schema, migrations, media/attachment storage |
| **ios-build-run** | Build, install, launch on Simulator; logs; deep links; test-mode |
| **ios-ui-automation** | ⭐ Agent drives the live app — tap/type/swipe, read a11y tree, screenshot, assert (idb + XcodeBuildMCP + ios-simulator-mcp + Maestro) |
| **xcuitest-writer** | Checked-in XCUITest E2E flows for CI |
| **swift-unit-tests** | Logic tests with Swift Testing (`import Testing`) |
| **snapshot-testing** | Pixel + view-tree tests for the design system (SnapshotTesting, ViewInspector) |
| **swift-bug-finder** | Hunt crashes, races, SQLiteData/GRDB/CloudKit + data-loss/privacy bugs |
| **test-requirements** | Turn a spec into a test plan + mandatory privacy/data-integrity cases |
| **swift-lint-format** | SwiftLint + swift-format + Periphery |
| **accessibility-audit** | VoiceOver/Dynamic Type/contrast + the identifiers automation needs |
| **ios-release-validator** | Pre-ship go/no-go; blocking privacy/data-integrity invariants; Apple review gates |
| **github-push** | 🔒 Mandatory pre-push gate — branch → local tests green → PR → green CI → merge; blocks secrets/privacy leaks. Required by `CLAUDE.md` before every push |
| **stage-review** | 🤖 Per-stage adversarial "does it break?" review over the whole stage diff — HIGH-severity bugs, privacy leaks, data-model/migration integrity. Runs automatically on every PR via `.github/workflows/stage-review.yml`, or manually as `/stage-review` |

⭐ = the headline capability: the AI actually operates and validates the app's UI.
🔒 = enforced on every push via the root `CLAUDE.md`.

## How they chain (a feature, end to end)
1. **test-requirements** — plan acceptance criteria + edge/privacy/data-integrity cases.
2. **swiftui-developer** (+ **persistence-setup** for data work) — implement to architecture + design system.
3. **swift-unit-tests** / **snapshot-testing** / **xcuitest-writer** — cover it at the cheapest layer.
4. **ios-build-run** → **ios-ui-automation** — build, then the agent drives the live UI and validates (light + dark).
5. **swift-bug-finder** + **swift-lint-format** + **accessibility-audit** — quality gates over the diff.
6. **ios-release-validator** — go/no-go before shipping.

## One-time setup for live UI validation
```bash
brew install idb-companion          # engine for UI automation MCPs
# create .mcp.json at repo root (Claude Code won't auto-write it) — snippet in ios-ui-automation/SKILL.md
```
Then approve the `XcodeBuildMCP` and `ios-simulator` servers when Claude Code prompts.

## CI (add when the Xcode project exists)
`xcodebuild test` on a `macos-26` GitHub Actions runner with `-enableCodeCoverage YES`; parse `xcrun xccov --json` to gate coverage. Full snippet lives in `swift-lint-format` / the build-plan doc (`docs/product/02-build-plan.md`). Not committed as a live workflow yet because there's no scheme to build.
