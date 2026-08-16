---
name: github-push
description: Mandatory pre-push gate for Journal — the checklist and exact steps to follow before ANY git push or pull request. Enforces branch → local tests green → PR → green CI → merge, protects main, and blocks pushing secrets or privacy leaks. Load and follow this every time you are about to push.
---

# GitHub Push Gate (Journal)

**This skill is REQUIRED before every `git push`.** `main` is branch-protected: no direct pushes, and the **Build & Test** CI check must be green before merge. Follow these steps in order — do not skip.

## 0. Never push to `main` directly
If you're on `main`, branch first:
```bash
git branch --show-current            # if this prints "main", STOP and branch
git switch -c feature/<short-name>   # or fix/<short-name>, chore/<short-name>
```

## 1. Pre-push safety checks (block the push if any fail)
- **No secrets.** Confirm no API keys, `.env`, `secrets.xcconfig`, or tokens are staged: `git diff --cached --name-only` and `git diff --cached | grep -iE 'api[_-]?key|secret|token|password'` → must be empty. (The Claude API key in particular must never be committed.)
- **No generated junk.** `Journal.xcodeproj/`, `DerivedData/`, `*.xcresult`, snapshot-failure PNGs must be gitignored, not committed.
- **Privacy invariant.** If the diff touches entries, export, AI, or sync, re-check the invariants: no readable entry text leaves the device without explicit per-entry opt-in; cloud AI sends only the user-selected text; entries E2EE at rest; export is human-readable and leaves no plaintext behind; data-safety features stay unpaywalled. A leak here blocks the push.

## 2. Build + test locally BEFORE pushing (green-before-push)
The whole point of this repo: *a small change must not break existing features.* Prove it locally first.
```bash
xcodegen generate
xcodebuild test -project Journal.xcodeproj -scheme Journal \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' CODE_SIGNING_ALLOWED=NO
```
All unit + UI tests must pass. If you changed UI, also sanity-check live per the `ios-ui-automation` skill. Lint via `swift-lint-format`.

If a new feature/bugfix has no matching test, add one (`test-requirements` → `swift-unit-tests` / `xcuitest-writer`) *before* pushing. New behavior ships with a regression test.

## 3. Commit
- Small, focused commits; imperative subject (e.g. "Add SQLiteData JournalEntry model").
- End every commit message with:
  ```
  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  ```

## 4. Push + open a PR
```bash
git push -u origin HEAD
gh pr create --fill        # CI runs automatically
```
PR body ends with:
```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## 5. Wait for green CI, then merge
```bash
gh pr checks --watch       # or: gh run watch
```
- **Do not merge until "Build & Test" is green.** Branch protection enforces this; don't bypass with admin override unless the user explicitly asks.
- `strict` is on — if `main` moved, update the branch (`git fetch && git rebase origin/main`) and let CI re-run.
- Merge only after green: `gh pr merge --squash --delete-branch`.

## 6. After merge
```bash
git switch main && git pull --ff-only
```

## Definition of done for a push
1. On a feature branch, not `main`.
2. No secrets / generated files staged; privacy invariant held.
3. Local `xcodebuild test` fully green; new behavior has a test.
4. Commit + PR messages carry the required trailers.
5. PR opened; **CI green** before merge; branch deleted after.
