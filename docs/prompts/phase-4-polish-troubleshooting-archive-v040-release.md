# Phase 4-polish — TROUBLESHOOTING entry + archive cleanup + v0.4.0 release

## Context
- Repo: `/Users/woody/Desktop/repo/public/woody-harness/` (32 commits in main; Phase 4d feedback loop just shipped)
- This is the **第 1 輪 polish 三連發**, pre-approved by user — auto-queued under `feedback_inbox_auto_queue` rule.
- 3 deliverables in one inbox run. After archive auto-commit = 4 commits + git tag + GitHub release.
- After this ships, executor stops. Planner waits for next user input.

## Working directory
**ALL commands from `/Users/woody/Desktop/repo/public/woody-harness/`.**

Pre-flight:
```bash
cd /Users/woody/Desktop/repo/public/woody-harness/
pwd
git status                  # must be clean
git pull --ff-only origin main
gh auth status              # must be authed for P-3 release step
```
If working tree dirty / pull conflicts / gh not authed — STOP and report.

## Commit convention (unchanged)
- Subject only, no co-author trailer.
- Types: `feat`, `fix`, `docs`, `chore`.

---

## Deliverables — 3 atomic commits + tag + release

### Commit 1 — P-2: TROUBLESHOOTING entry "通知沒響"

**Purpose**: codify today's lesson — when /inbox finishes silently, check system silent / Focus / volume before suspecting harness bug.

**File**: `docs/TROUBLESHOOTING.md` — APPEND a new entry. Read the file first to match existing format. Add at the **end** of the entry list (after the last `### ...` block, before any `## Still stuck?` section). New entry:

```markdown
### `/inbox` finished but no notification sound or banner

**Symptom**: Executor reports "Notification fired: yes — Glass sound" with exit 0, but you heard / saw nothing.

**Cause** (in order of likelihood):
1. **macOS sleep silent / Focus Mode / DND is on** — system silently drops all notifications and notification-bound sounds.
2. **Audio output routed to a Bluetooth device that's disconnected or muted**.
3. **System volume at 0**.
4. (rare) `osascript -e 'display notification ... sound name "Glass"'` host app is `Script Editor`, which doesn't have Notifications permission in System Settings → Notifications. Visual notification + bound sound silently dropped.

**Fix**:
- Step 1: confirm audio path works at all — `afplay /System/Library/Sounds/Glass.aiff`. If you don't hear it, the issue is system-wide (volume / Focus / silent mode), not the harness.
- Step 2: if afplay works but `/inbox` notification doesn't — open System Settings → Notifications → Script Editor → enable "Allow Notifications".
- Step 3: if you want guaranteed audio regardless of Focus state, the harness's `/inbox` slash command can be edited to use `afplay /System/Library/Sounds/Glass.aiff &` for sound (always plays) plus `osascript display notification` for visual (best-effort).
```

**Commit subject**: `docs: TROUBLESHOOTING — entry for "no notification sound" diagnosis`

---

### Commit 2 — P-1: actually run archive-prompts.sh (move 2 legacy files)

**Purpose**: validate the archive script in the wild + clean `docs/prompts/` clutter. The script's own dry-run (Phase 4d) listed 2 legacy `phase-*.md` files queued for `_archive/legacy/`.

**Steps**:
```bash
# Confirm what will move
bash scripts/archive-prompts.sh --dry-run
# Now actually run
bash scripts/archive-prompts.sh
# Verify moves are staged
git status
```
Expected: `phase-4b-onboarding-docs-memory-resume.md`, `phase-4c-examples-hello-cli.md`, `phase-4d-feedback-loop-outbox-notification.md` (or whatever current dated archives exist) moved into `docs/prompts/_archive/<YYYY-MM>/` or `_archive/legacy/`. NOTE: the archive of the CURRENT inbox prompt (this one, named `phase-4-polish-...`) will be created BY the /inbox slash command after this commit, so don't worry about it now.

If `git status` shows the moves correctly:
```bash
git add -A
git commit -m "chore: archive prompts to _archive/legacy/"
```

If the script errors or moves an unexpected file (e.g., active `_inbox.md` or `README.md`) — STOP and report; don't commit.

**Commit subject**: `chore: archive prompts to _archive/legacy/`

(Adjust subject if the script's actual run produces a different bucket name.)

---

### Commit 3 — P-3: CHANGELOG bump + v0.4.0 release ceremony

**Purpose**: 4d is a natural milestone. Cut a tagged release.

**Step A: Update CHANGELOG.md**

Read current `CHANGELOG.md`. Currently has `## [Unreleased]` section listing Phase 4a/4b/4c entries. Two changes:

1. Under `## [Unreleased]`, **add** the Phase 4d entries that aren't yet there:
   - Under `### Added` (existing or new):
     ```
     - `.claude/settings.json` permissions allowlist for `osascript`, `say`, archive helper (Phase 4d)
     - `scripts/archive-prompts.sh` manual prompt archive helper (Phase 4d)
     - `bootstrap.sh` copies archive helper to new projects (Phase 4d)
     ```
   - Under `### Changed`:
     ```
     - `.claude/commands/inbox.md` rewritten — every `/inbox` run now appends a `## Result` block to the archived prompt and fires a macOS notification (Phase 4d feedback loop).
     ```

2. **Rename** `## [Unreleased]` to `## [0.4.0] - 2026-04-28`. (Preserve all bullet content.)

3. Ensure file ends with a single trailing newline.

**Step B: git tag + push tag**
```bash
git add CHANGELOG.md
git commit -m "docs: CHANGELOG bump 0.4.0 — Phase 4 (a/b/c/d) cumulative release"
git tag -a v0.4.0 -m "v0.4.0 — Phase 4 cumulative (legal/entry + onboarding docs + examples + feedback loop)"
git push origin main
git push origin v0.4.0
```

**Step C: GitHub Release via gh**

Extract the `## [0.4.0]` body from CHANGELOG.md (everything between that heading and the next `## [` heading, exclusive) and use it as the release notes. Implementation:

```bash
# Extract body (awk between [0.4.0] and next [version])
awk '/^## \[0\.4\.0\]/,/^## \[0\.2\.0\]/' CHANGELOG.md | sed '$d' | sed '1d' > /tmp/release-notes.md
cat /tmp/release-notes.md   # eyeball — should start with "### Added" or similar, end before "## [0.2.0]"

gh release create v0.4.0 \
  --title "v0.4.0 — Phase 4 cumulative" \
  --notes-file /tmp/release-notes.md
```

If `gh release create` fails (e.g., release already exists / auth issue) — STOP and report; don't try to force.

**Commit subject** (for the CHANGELOG bump commit): `docs: CHANGELOG bump 0.4.0 — Phase 4 (a/b/c/d) cumulative release`

---

## After all 3 commits + tag + release
```bash
git log --oneline -8
git tag -l
gh release list --limit 5
git status
bash scripts/archive-prompts.sh --dry-run
```

## Hard constraints
1. **NO co-author / Claude trailers** in commits.
2. **DO NOT** modify files outside: `docs/TROUBLESHOOTING.md` (commit 1), files moved by the archive script (commit 2), `CHANGELOG.md` (commit 3).
3. **DO NOT** start the next sequence (S-2 memory export/import) — auto-queue authorization expires after this 3-commit polish round per `feedback_inbox_auto_queue` rule.
4. If `gh auth status` fails in pre-flight — STOP, do not attempt P-3 step C without auth.
5. If the awk extraction in Step C produces empty / wrong output, STOP — do not push a malformed release. Manually inspect and fix the awk pattern, or fall back to `gh release create v0.4.0 --notes "Phase 4 cumulative release. See CHANGELOG.md for details."`.
6. Tag `v0.4.0` MUST point at the CHANGELOG bump commit (commit 3), not earlier.

## Reply format when done
Per current `/inbox` convention: append `## Result` block to archived prompt + fire macOS notification + reply 1-2 sentences in 繁中 with archive path. The convention handles the rest. Just include in the Result block:

```
**Status**: ✅ shipped
**Commits**: 3 (+ archive auto-commit + tag + release)
<git log --oneline of the 3 deliverable commits>

**Verification**:
- TROUBLESHOOTING entry visible: yes
- Archive script run: <N> files moved to _archive/...
- Tag v0.4.0 pushed: yes
- GitHub release created: <URL>

**Push**: ✅ pushed to origin/main + tag pushed
**Blockers**: <none | description>
```

Then stop. **Do NOT** auto-queue S-2 or anything else (auto-queue authorization is sequence-bounded; this sequence ends here).

## Result

**Status**: ✅ shipped
**Commits**: 3 (+ archive auto-commit + tag + release)
64c4d6e docs: TROUBLESHOOTING — entry for "no notification sound" diagnosis
1ad9876 chore: archive prompts to _archive/legacy/
7f55a78 docs: CHANGELOG bump 0.4.0 — Phase 4 (a/b/c/d) cumulative release

**Verification**:
- TROUBLESHOOTING entry visible: yes (appended before "## Still stuck?")
- Archive script run: 3 files moved to docs/prompts/_archive/legacy/
- Tag v0.4.0 pushed: yes
- GitHub release created: https://github.com/woodylin0920-bit/woody-harness/releases/tag/v0.4.0

**Push**: ✅ pushed to origin/main + v0.4.0 tag pushed
**Blockers**: none
