---
name: ios-ui-automation
description: Drive the running Journal app in the Simulator like a user — tap, type, swipe, read the on-screen accessibility tree, screenshot, and assert UI state. Use to validate a feature end-to-end through the real UI, reproduce a UI bug, or confirm a screen renders/behaves correctly.
---

# AI-Driven iOS UI Automation & Validation

This is how the agent *itself* operates the app and checks it — not by reading code, but by touching the running UI and looking at the result. Two layers: a **structural** check (accessibility tree — did the right elements appear?) and a **visual** check (screenshot — did the UI actually render?).

## Preferred path: MCP servers
When connected, use the MCP tools directly — they wrap everything below:
- **XcodeBuildMCP**: `build_run_sim`, `launch_app_sim`, `screenshot`, `tap`, `swipe`, `type_text`, `describe_ui`.
- **ios-simulator-mcp**: `get_booted_sim_id`, `launch_app`, `ui_describe_all` (a11y tree), `ui_find_element`, `ui_tap`, `ui_type`, `ui_swipe`, `ui_view` (returns a compressed screenshot inline so the model can *look* at it), `screenshot`, `record_video`.

### Add the MCP servers (one-time, user runs this)
Both UI-automation MCPs shell out to `idb_companion`, so install it first, then create `.mcp.json` at the repo root:
```bash
brew install idb-companion
```
```json
{
  "mcpServers": {
    "XcodeBuildMCP": { "command": "npx", "args": ["-y", "xcodebuildmcp@latest"] },
    "ios-simulator": { "command": "npx", "args": ["-y", "ios-simulator-mcp"] }
  }
}
```
(Claude Code will not auto-write `.mcp.json` — the user must create it and approve the servers.)

## Fallback path: idb + simctl CLI
```bash
# install once
brew tap facebook/fb && brew install idb-companion
pip3 install fb-idb          # Python 3.11+

# interact (default target = booted sim)
idb ui describe-all          # full accessibility tree as JSON: labels, types, frames (x,y,w,h)
idb ui tap 200 400           # tap at coordinate (compute from a frame in describe-all)
idb ui text "Morning walk"   # type into the focused field
idb ui swipe 100 500 100 150 # x1 y1 x2 y2
idb screenshot shot.png
xcrun simctl io booted screenshot shot.png   # simctl alternative for screenshots
```

## The validation loop (do this for every UI check)
1. **Launch** the app (`ios-build-run` or MCP `launch_app_sim`), ideally with `-uiTesting` for deterministic data.
2. **Act** — tap/type/swipe toward the state you're validating.
3. **Read structure** — `ui_describe_all` / `idb ui describe-all`. Assert the expected elements exist by their `accessibilityIdentifier`/label, and read values. This is your source of truth for "did the flow work."
4. **Look** — `ui_view` or a screenshot. Verify the things the tree can't tell you: gradient/blur/translucency, layout, the 3D emoji rendered, nothing clipped or overlapping.
5. **Both appearances** — re-check in dark mode: `xcrun simctl ui booted appearance dark`.
6. **Report** — state what you did, what you observed, and pass/fail with the screenshot as evidence.

## Why accessibility identifiers are mandatory
Coordinate taps and text-label matches are fragile (localization, emoji, dynamic copy, glassy styling shifting frames). Every interactive/asserted view MUST set a stable id:
```swift
Button("New Entry") { … }.accessibilityIdentifier("newEntryButton")
MoodPicker(selection: $mood).accessibilityIdentifier("moodPicker")
```
Then locate with `ui_find_element("newEntryButton")` regardless of copy. **If you find a view you need to automate that lacks an identifier, add one** — treat missing identifiers as a bug in testability.

## Example: validate the "create an entry" flow
1. `launch_app_sim` with `-uiTesting`.
2. `ui_find_element("newEntryButton")` → `ui_tap`.
3. `ui_type` into `entryComposerTextEditor`, tap a mood in `moodPicker`, `ui_tap("saveEntryButton")`.
4. `ui_describe_all` → assert an element with id `entryRow` (or the saved title) exists in the timeline.
5. `ui_view` → confirm the entry card rendered on glass and the mood emoji shows.
6. Repeat in dark mode. Report pass/fail + screenshots.

## Repeatable regression flows (Maestro)
For checked-in, deterministic flows (vs. free-form agent exploration), use Maestro YAML:
```bash
brew install maestro
maestro test flows/create-entry.yaml
```
```yaml
appId: com.you.journal
---
- launchApp
- tapOn: { id: "newEntryButton" }
- inputText: "Morning walk by the river"
- tapOn: { id: "saveEntryButton" }
- assertVisible: { id: "entryRow" }
```
Keep these under `flows/` and run them in CI after a build.
