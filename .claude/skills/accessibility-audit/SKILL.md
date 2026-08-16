---
name: accessibility-audit
description: Audit and fix accessibility in the Journal SwiftUI app — VoiceOver labels, Dynamic Type, contrast (critical for glass/material surfaces), and stable accessibilityIdentifiers that make UI automation reliable. Use when reviewing UI code, before shipping a screen, or when automation can't find elements.
---

# Accessibility Audit (and testability)

Accessibility here does double duty: it's the right thing for users **and** it's what makes `ios-ui-automation` reliable (the automation reads the same accessibility tree VoiceOver uses).

## 1. Identifiers for automation (do this on every interactive view)
```swift
Button("New Entry") { … }.accessibilityIdentifier("composeEntryButton")
```
- Identifiers are invisible to users but stable for tests — decouple from copy/localization.
- Naming convention: `<screen><Element><Role>` → `homeComposeEntryButton`, `entryComposerTextEditor`, `moodPickerButton`, `todoDueDateField`.
- Containers/cards too, so automation can scope queries (e.g. `entryCard`, `attachmentRow`).

## 2. VoiceOver labels & semantics
- Give icon-only buttons a label: `.accessibilityLabel("New entry")`. SF Symbols alone read poorly.
- Combine decorative + meaningful text: mark pure decoration `.accessibilityHidden(true)` (e.g. ambient background, the 3D mood emoji when it's ornamental).
- The mood picker: expose a value, not just an image — `.accessibilityLabel("Mood")`, `.accessibilityValue("Content")`.
- Group related bits: `.accessibilityElement(children: .combine)` on an entry card so VoiceOver reads it as one unit.
- Custom controls get traits: `.accessibilityAddTraits(.isButton)` / `.isSelected` (e.g. a selected tag chip or todo checkbox).

## 3. Dynamic Type
- Use text styles (`.font(.title)`, `.body`), never hard-coded point sizes, so text scales.
- Verify at the largest accessibility sizes — cards and the composer must grow, not clip:
  ```bash
  xcrun simctl ui booted content-size accessibility-extra-extra-extra-large
  ```
- Prefer layouts that reflow (`ViewThatFits`, wrapping stacks) over fixed heights on text.

## 4. Contrast — the glass trap
Glassmorphism / Liquid Glass is a documented contrast hazard. Hard rules:
- **Never set body/data text directly on glass or a gradient.** Put it on a solid or ≥90%-opacity fill (a `.regularMaterial` card, not `.glassEffect()`, behind dense text).
- Body text vs. its background must meet **WCAG AA 4.5:1** (3:1 for large text).
- Don't rely on color alone to signal state (e.g. done vs pending todo) — pair with shape/icon (filled vs empty checkbox).

## 5. Reduce Motion
- Springy transitions, Pow change effects, and Vortex particles must calm down under Reduce Motion: check `@Environment(\.accessibilityReduceMotion)` and drop/shorten animations.
  ```bash
  xcrun simctl ui booted increase-contrast enabled   # also exercise increased-contrast
  ```

## Audit procedure
1. Grep the changed SwiftUI for interactive views missing `accessibilityIdentifier` → add them.
2. Launch with `ios-ui-automation`, run `ui_describe_all`, confirm every actionable element has a sensible label/identifier and value.
3. Bump content size to accessibility-XXXL and screenshot — check for clipping/overlap.
4. Screenshot in dark mode + increased contrast — eyeball text legibility on glass.
5. Report violations as fixes (label, contrast, scaling), not just observations.
