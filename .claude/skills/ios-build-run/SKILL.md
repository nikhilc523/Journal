---
name: ios-build-run
description: Build, install, and launch the Journal iOS app on a Simulator, and stream logs. Use when asked to build/run/compile the app, boot a simulator, install a build, or reproduce a runtime issue.
---

# iOS Build & Run (Simulator)

The build/run loop for the Journal SwiftUI app. Prefer **XcodeBuildMCP** tools when the MCP server is connected (see `ios-ui-automation`); the raw commands below are the fallback and the ground truth.

## Find the target simulator
```bash
xcrun simctl list devices available          # UDIDs + booted state
xcrun xcodebuild -list -project Journal.xcodeproj   # schemes/targets (or -workspace)
```

## Build
```bash
# Simulator build (no signing needed)
xcodebuild build \
  -scheme Journal \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO
```
The built `.app` lands at `DerivedData/Build/Products/Debug-iphonesimulator/Journal.app`.

## Boot, install, launch
```bash
xcrun simctl boot "iPhone 17"                                  # or a UDID; ignore if already booted
open -a Simulator                                              # bring the sim window up
xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/Journal.app
xcrun simctl launch booted com.you.journal                     # replace with real bundle id
```

## Logs & diagnostics
```bash
xcrun simctl launch --console-pty booted com.you.journal       # launch with console attached
xcrun simctl spawn booted log stream --level debug --predicate 'process == "Journal"'
```

## Useful state controls (also handy for validation)
```bash
xcrun simctl ui booted appearance dark        # toggle dark/light — verify the UI in both
xcrun simctl openurl booted "journal://new"   # exercise deep links (e.g. new-entry)
xcrun simctl io booted screenshot shot.png    # capture current screen
xcrun simctl erase booted                     # wipe to a clean state (destructive)
```

## Test-mode launch arguments
Launch with `-uiTesting` so the app uses an in-memory database and disables CloudKit sync for deterministic runs (see `xcuitest-writer`):
```bash
xcrun simctl launch booted com.you.journal -uiTesting
```

## Guidance
- Pin `name`/`OS` to a simulator the machine actually has (`simctl list devices`) — mismatches are the #1 cause of "destination not found".
- After a code change, rebuild → reinstall → relaunch. `simctl install` over an existing install updates it in place.
- If the build fails, read the first error, not the last — Swift error cascades bury the root cause up top.
- For a full launch-and-screenshot verification of a change, hand off to the `run` or `verify` skill, or `ios-ui-automation` for interactive validation.
