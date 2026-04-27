# Phase 4-polish round 4 — Notification hook + templates/_inbox cleanup

## Context
- Repo: `/Users/woody/Desktop/repo/public/woody-harness/` (41 commits + v0.4.0; round 3 just shipped 29/29 checks)
- Pre-approved 第 4 輪 polish per `feedback_inbox_auto_queue` rule
- Solves two open friction points:
  1. Executor cards on permission prompt / 60s idle — no audio cue (current Glass only fires at /inbox completion)
  2. Fresh bootstrap shows `📥 queued: # (empty inbox — ...)` in statusline because template `_inbox.md` has placeholder comment, file size > 5 bytes — cosmetic but misleading
- 2 deliverable commits + archive auto-commit = 3 commits
- After this ships, executor stops. Auto-queue authorization expires.

## Working directory
**ALL commands from `/Users/woody/Desktop/repo/public/woody-harness/`.**

Pre-flight:
```bash
cd /Users/woody/Desktop/repo/public/woody-harness/
git status                  # must be clean
git pull --ff-only origin main
ls .claude/                 # baseline
ls scripts/                 # baseline: archive-prompts.sh, memory.sh, statusline.sh, test-bootstrap.sh, session-briefing.sh
```

## Commit convention (unchanged)
- Subject only, no co-author trailer.
- Types: `feat`, `fix`, `docs`, `chore`.

---

## Deliverables — 2 atomic commits + archive

### Commit 1 — Notification hook + alert script + TROUBLESHOOTING + test assert

**Purpose**: when Claude Code executor is blocked on permission prompt OR idle >60s waiting for input, fire afplay Funk + macOS notification banner. Closes the "Glass only fires on completion, not on blocked" gap.

**File 1**: `scripts/notify-blocked.sh` (new) — full content:
```bash
#!/usr/bin/env bash
# notify-blocked.sh — alert when Claude Code executor is blocked (permission prompt / idle).
# Triggered by Notification event hook in .claude/settings.json.
# afplay backgrounded so the hook returns instantly; osascript best-effort.
afplay /System/Library/Sounds/Funk.aiff &
osascript -e 'display notification "⚠️ executor needs your input" with title "woody-harness · blocked"' 2>/dev/null || true
```

**File 2 edit**: `.claude/settings.json` — ADD a `Notification` event hook to the existing `hooks` block. Read current file first to preserve `statusLine`, `permissions`, `hooks.SessionStart` exactly. Add a sibling key `Notification` under `hooks`:
```json
"Notification": [
  {
    "matcher": "*",
    "hooks": [
      {
        "type": "command",
        "command": "bash scripts/notify-blocked.sh"
      }
    ]
  }
]
```

ALSO add to `permissions.allow` array: `"Bash(bash scripts/notify-blocked.sh:*)"` (consistency with other script entries; matters if Sonnet ever wants to test it manually).

Verify: `python3 -c "import json; json.load(open('.claude/settings.json')); print('OK')"`.

**File 3 edit**: `bootstrap.sh` — find `# Copy archive helper` block (Phase 4d) where existing scripts are copied. After the existing `cp ... statusline.sh ...` line (added in round 3), ADD:
```bash
cp "$HARNESS_DIR/scripts/notify-blocked.sh" scripts/notify-blocked.sh
```

**File 4 edit**: `docs/TROUBLESHOOTING.md` — APPEND a new entry at the end of the entry list (after the last `### ...` block, before any `## Still stuck?` section). Match existing format:

```markdown
### Executor stalled silently — no Glass sound but no progress either

**Symptom**: `/inbox` is running but you don't see new commits and you didn't hear Glass. Switching to the executor terminal you find a permission dialog or "Claude is waiting for input" prompt that's been sitting for ages.

**Cause**: The Phase 4d Glass notification only fires at `/inbox` completion. Permission prompts and 60-second idle states are separate Claude Code events — without a hook on those, you sit blind.

**Fix**: After Phase 4-polish round 4 ships, the harness installs a `Notification` event hook (`.claude/settings.json` + `scripts/notify-blocked.sh`) that fires Funk sound + macOS banner when the executor needs your attention. If you're on a fork before round 4 — pull latest, or manually add the hook. Pre-authorize common edits via permissions allowlist (e.g. `"Edit(.claude/**)"`) to reduce permission prompt frequency.

**Pre-emptive workaround during a stuck session**: choose option 2 ("Yes, and allow Claude to edit its own settings for this session") on permission prompts to unblock for the rest of the session.
```

**File 5 edit**: `scripts/test-bootstrap.sh` — find the existing assertions block. Add 2 more `assert` calls in the appropriate sections:
- Under the `=== File presence ===` block: `assert "scripts/notify-blocked.sh exists" test -f scripts/notify-blocked.sh`
- Under a NEW or existing `=== settings.json content ===` section: `assert "Notification hook present" "grep -q Notification .claude/settings.json"`

(If no `=== settings.json content ===` section exists, add it as a new section header just before `=== Scripts runnable ===`.)

**Verification BEFORE committing**:
```bash
# 1. notify-blocked.sh runs (don't actually want Funk to fire 3x during testing — skip running it)
test -x scripts/notify-blocked.sh || test -r scripts/notify-blocked.sh   # exists + readable

# 2. JSON valid
python3 -c "import json; d=json.load(open('.claude/settings.json')); assert 'Notification' in d['hooks']; print('OK Notification hook present')"

# 3. test-bootstrap still passes
bash scripts/test-bootstrap.sh
# Expected: PASS 31/31 (was 29/29; +2 new asserts)

# 4. bootstrap dry-run carries notify-blocked.sh
cd /tmp && rm -rf wh-r4-test
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh wh-r4-test
test -f /tmp/wh-r4-test/scripts/notify-blocked.sh && echo OK
test -f /tmp/wh-r4-test/.claude/settings.json && grep -q Notification /tmp/wh-r4-test/.claude/settings.json && echo "Notification hook copied OK"
rm -rf /tmp/wh-r4-test
rm -rf "$HOME/.claude-work/projects/-tmp-wh-r4-test"
cd /Users/woody/Desktop/repo/public/woody-harness/
```

If any step fails — FIX before committing.

**Commit subject**: `feat: Notification event hook + scripts/notify-blocked.sh — alert on blocked executor`

---

### Commit 2 — `templates/prompts/_inbox.md` truly empty + statusline "empty" assert

**Purpose**: fix cosmetic bug where fresh bootstrap shows `📥 queued: # (empty inbox — ...)` in statusline. The placeholder comment was 84 bytes, statusline.sh threshold is 5 bytes, so it incorrectly registered as queued.

**File 1**: `templates/prompts/_inbox.md` — REPLACE entire content with a single newline (i.e., the file is just `\n`, 1 byte).

The placeholder explanation was helpful for new users but `docs/prompts/README.md` (also bootstrap-copied) already covers it more thoroughly. The empty `_inbox.md` is the correct convention — empty means "no queued task".

**File 2 edit**: `scripts/test-bootstrap.sh` — add an assert verifying fresh bootstrap's statusline shows "empty" (not "queued"):
- Under a NEW or existing `=== Statusline ===` section (add it just before `=== Scripts runnable ===` if absent), add:
  ```
  assert "statusline shows empty on fresh bootstrap" "bash scripts/statusline.sh | grep -q 'empty'"
  ```

(test-bootstrap.sh runs from inside the test bootstrap project, so `bash scripts/statusline.sh` resolves to the bootstrapped project's copy.)

**Verification BEFORE committing**:
```bash
# 1. template inbox is now 1 byte
wc -c < templates/prompts/_inbox.md
# Expected: 1

# 2. test-bootstrap passes (now 32/32 with the new statusline assert)
bash scripts/test-bootstrap.sh
# Expected: PASS 32/32

# 3. fresh bootstrap statusline shows "empty"
cd /tmp && rm -rf wh-r4b-test
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh wh-r4b-test
cd /tmp/wh-r4b-test && bash scripts/statusline.sh
# Expected: "📥 empty · <SHA> chore: bootstrap from woody-harness · last: —"
cd /Users/woody/Desktop/repo/public/woody-harness/
rm -rf /tmp/wh-r4b-test
rm -rf "$HOME/.claude-work/projects/-tmp-wh-r4b-test"
```

If statusline still shows "queued" — debug: maybe templates/prompts/_inbox.md still has hidden bytes, or statusline.sh threshold logic. Fix before committing.

**Commit subject**: `fix: templates/prompts/_inbox.md truly empty so fresh bootstrap statusline shows "empty"`

---

## Hard constraints
1. **NO co-author / Claude trailers** in commits.
2. **DO NOT** modify files outside: `scripts/notify-blocked.sh` (commit 1, new), `.claude/settings.json` (commit 1), `bootstrap.sh` (commit 1), `docs/TROUBLESHOOTING.md` (commit 1), `scripts/test-bootstrap.sh` (both commits), `templates/prompts/_inbox.md` (commit 2).
3. **DO NOT** start any next task — auto-queue authorization expires after this round. Even if T-1/S-1 seem natural to chain, STOP.
4. Settings.json must remain valid JSON after edit — verify with `python3 -c "import json; json.load(open('.claude/settings.json'))"`.
5. If `bash scripts/test-bootstrap.sh` fails after EITHER commit — STOP. test-bootstrap is the regression net.
6. Cleanup any `/tmp/wh-r4*-test` dirs and corresponding `~/.claude-work/projects/-tmp-...` memory dirs after verification.

## Reply format when done
Per current `/inbox` convention (Result block + osascript notification + 1-2 sentence 繁中 reply). Result block include:

```
**Status**: ✅ shipped
**Commits**: 2 (+ archive auto-commit)
<git log --oneline of the 2 deliverable commits>

**Verification**:
- notify-blocked.sh: present + readable
- Notification hook in settings.json: yes (JSON valid)
- bootstrap copies notify-blocked.sh: yes
- TROUBLESHOOTING entry added: yes
- templates/_inbox.md size: 1 byte
- test-bootstrap.sh: PASS N/N (was 29/29, expect 32/32 after both commits)
- Fresh bootstrap statusline shows "empty": yes

**Push**: ✅ pushed to origin/main
**Blockers**: <none | description>
```

Then stop. Do NOT auto-queue T-1 / S-1 / 4e — auto-queue authorization is sequence-bounded.

## Result

**Status**: ✅ shipped
**Commits**: 2 (+ archive auto-commit)
143dfe2 fix: templates/prompts/_inbox.md truly empty so fresh bootstrap statusline shows "empty"
ec09302 feat: Notification event hook + scripts/notify-blocked.sh — alert on blocked executor

**Verification**:
- notify-blocked.sh: present + readable + executable
- Notification hook in settings.json: yes (JSON valid, asserted via grep)
- bootstrap copies notify-blocked.sh: yes (verified via /tmp/wh-r4-test)
- TROUBLESHOOTING entry added: yes (new "Executor stalled silently" entry)
- templates/_inbox.md size: 1 byte
- test-bootstrap.sh: PASS 32/32 (was 29/29; +2 for r4-commit-1, +1 for r4-commit-2)
- Fresh bootstrap statusline shows "empty": yes — `📥 empty · 8142d9b chore: bootstrap from woody-harness · last: —`

**Push**: ✅ pushed to origin/main
**Blockers**: none
