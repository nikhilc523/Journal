---
name: swift-lint-format
description: Lint and format Swift code for Journal with SwiftLint and apple/swift-format, and find dead code with Periphery. Use when setting up code-quality tooling, before committing, or when asked to clean up / enforce style.
---

# Swift Lint & Format

## SwiftLint (style + convention rules)
```bash
brew install swiftlint
swiftlint            # lint
swiftlint --fix      # autocorrect what's safe
swiftlint analyze    # compiler-backed semantic rules (needs a compile log)
```
`.swiftlint.yml` at repo root:
```yaml
disabled_rules: [trailing_whitespace]
opt_in_rules:
  - empty_count
  - force_unwrapping      # flag ! — see swift-bug-finder
  - force_cast
  - force_try
  - weak_delegate
excluded: [.build, DerivedData, "**/*.generated.swift"]
line_length: 120
identifier_name:
  min_length: 2
```
Xcode Run Script build phase (after Compile Sources; uncheck "Based on dependency analysis"):
```sh
if command -v swiftlint >/dev/null; then swiftlint; else echo "warning: SwiftLint not installed"; fi
```

## swift-format (formatting)
```bash
brew install swift-format           # or use the toolchain's `swift format`
swift-format init > .swift-format    # generate config, then tune lineLength/indentation
swift-format lint --recursive Sources
swift-format format --in-place --recursive Sources
```

## Periphery (dead code)
```bash
brew install peripheryapp/periphery/periphery
periphery scan --setup      # first time — writes .periphery.yml
periphery scan              # thereafter — unused types/props/imports
```

## Workflow
- Run `swiftlint --fix` + `swift-format format --in-place` before every commit.
- Keep `force_unwrapping`/`force_cast`/`force_try` **on** — they catch the crash-prone patterns the `swift-bug-finder` skill hunts.
- Run `periphery scan` periodically, not on every commit (it needs a full build).
- Don't fight the formatter — configure it once, then let it own whitespace so reviews stay about logic.
