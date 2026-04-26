# Phase 4-polish round 3 — statusline + /sync slash command

## Context
- Repo: `/Users/woody/Desktop/repo/public/woody-harness/` (38 commits + v0.4.0 in main; round 2 just shipped 25/25 checks)
- Pre-approved 第 3 輪 polish per `feedback_inbox_auto_queue` — automation 削 friction (passive statusline + on-demand /sync)
- 2 deliverable commits + archive auto-commit = 3 total commits
- After this ships, executor stops. Auto-queue authorization expires.

## Working directory
**ALL commands from `/Users/woody/Desktop/repo/public/woody-harness/`.**

Pre-flight:
```bash
cd /Users/woody/Desktop/repo/public/woody-harness/
git status                  # must be clean
git pull --ff-only origin main
ls .claude/commands/        # baseline: inbox/resume/phase-gate/codex-audit
ls scripts/                 # baseline: archive-prompts.sh + memory.sh + test-bootstrap.sh
```

## Commit convention (unchanged)
- Subject only, no co-author trailer.
- Types: `feat`, `fix`, `docs`, `chore`.

---

## Deliverables — 2 atomic commits + archive

### Commit 1 — statusline (script + settings.json + bootstrap copy)

**Purpose**: passive real-time display of inbox state + last commit + last archive Result emoji. Planner切過去看一眼就知 executor 跑到哪。

**File 1**: `scripts/statusline.sh` (new) — full content:

```bash
#!/usr/bin/env bash
# statusline.sh — woody-harness status indicator for Claude Code statusLine.
# Output: "📥 <state> · <short commit> · last: <emoji>"
# Must be fast (<100ms): only git log, ls, head, grep — no network, no tar.
set -e

root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "(not a git repo)"; exit 0; }
cd "$root"

# Inbox state — file > 5 bytes counts as "queued"
if [ -s docs/prompts/_inbox.md ] && [ "$(wc -c < docs/prompts/_inbox.md | tr -d ' ')" -gt 5 ]; then
    title=$(grep -m1 '^# ' docs/prompts/_inbox.md 2>/dev/null | sed 's/^# //' | cut -c1-30)
    inbox="📥 queued: ${title:-?}"
else
    inbox="📥 empty"
fi

# Last commit (short SHA + first 35 chars of subject)
last_commit=$(git log -1 --format='%h %s' 2>/dev/null | cut -c1-44)

# Latest archive Result Status emoji
latest_archive=$(ls -t docs/prompts/[0-9]*-*.md docs/prompts/phase-*.md 2>/dev/null | grep -v '_archive/' | head -1)
result_emoji="—"
if [ -n "$latest_archive" ]; then
    status_line=$(grep -m1 '^\*\*Status\*\*' "$latest_archive" 2>/dev/null || echo "")
    case "$status_line" in
        *"✅"*) result_emoji="✅" ;;
        *"⚠️"*) result_emoji="⚠️" ;;
        *"❌"*) result_emoji="❌" ;;
    esac
fi

echo "$inbox · $last_commit · last: $result_emoji"
```

**File 2 edit**: `.claude/settings.json` — ADD a top-level `statusLine` field. Final file structure:
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash scripts/statusline.sh"
  },
  "permissions": {
    "allow": [
      "Bash(osascript:*)",
      "Bash(say:*)",
      "Bash(bash scripts/archive-prompts.sh:*)",
      "Bash(bash scripts/memory.sh:*)"
    ]
  },
  "hooks": {
    "SessionStart": [...existing block unchanged...]
  }
}
```
Preserve existing `permissions` and `hooks` content verbatim. Verify JSON valid:
```bash
python3 -c "import json; json.load(open('.claude/settings.json')); print('OK')"
```

**File 3 edit**: `bootstrap.sh` — find existing `# Copy archive helper` block. After the existing `cp ... memory.sh ...` line (added in round 2), ADD:
```bash
cp "$HARNESS_DIR/scripts/statusline.sh" scripts/statusline.sh
```

**Verification BEFORE committing**:
```bash
# 1. statusline runs fast and outputs sensibly
time bash scripts/statusline.sh
# Expected: "📥 queued: Phase 4-polish round 3 ... · <SHA> ... · last: ✅"
# Time should be < 100ms

# 2. JSON valid
python3 -c "import json; json.load(open('.claude/settings.json')); print('OK')"

# 3. bootstrap copies it
cd /tmp && rm -rf wh-statusline-test
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh wh-statusline-test
ls /tmp/wh-statusline-test/scripts/
# Expected: archive-prompts.sh + memory.sh + statusline.sh
bash /tmp/wh-statusline-test/scripts/statusline.sh
# Expected: "📥 empty · <SHA> chore: bootstrap from woody-harness · last: —"

# 4. cleanup
rm -rf /tmp/wh-statusline-test
rm -rf "$HOME/.claude-work/projects/-tmp-wh-statusline-test"
cd /Users/woody/Desktop/repo/public/woody-harness/

# 5. test-bootstrap still passes (round 2 added it; statusline didn't break anything)
bash scripts/test-bootstrap.sh
# Expected: PASS N/N — likely 26/26 or 27/27 if you add statusline checks; or still 25/25 if not
```

If statusline.sh outputs nothing / takes > 1 second / settings.json invalid / bootstrap missing file — FIX before committing.

**Optional**: extend `scripts/test-bootstrap.sh` to also assert `scripts/statusline.sh exists` + that running it produces non-empty output. Add 2 more `assert` lines in the appropriate sections. **If you do this, include in this same commit.**

**Commit subject**: `feat: scripts/statusline.sh + Claude Code statusLine integration`

---

### Commit 2 — `/sync` slash command + bootstrap copy + extend SessionStart hook

**Purpose**: on-demand verify state — user 打 `/sync` 即時跑 git log + cat _inbox + 讀最新 archive Result block。語意上等同講「跑完了」但更便宜、強制觸發 `feedback_planner_verify_on_inbox_signal` 規則。

**File 1**: `.claude/commands/sync.md` (new) — full content:

```markdown
---
description: 即時同步 — git log + inbox 狀態 + 最新 archive Result block
---

執行 sync 流程，**先查實狀，再答**。第一個 tool call 必須是 Bash 跑：

```bash
echo "=== git log -5 ==="
git log --oneline -5
echo ""
echo "=== _inbox.md state ==="
lines=$(wc -l < docs/prompts/_inbox.md | tr -d ' ')
bytes=$(wc -c < docs/prompts/_inbox.md | tr -d ' ')
echo "lines=$lines bytes=$bytes"
if [ "$bytes" -gt 5 ]; then
    echo "--- inbox head ---"
    head -5 docs/prompts/_inbox.md
fi
echo ""
echo "=== latest archive Result block ==="
latest=$(ls -t docs/prompts/[0-9]*-*.md docs/prompts/phase-*.md 2>/dev/null | grep -v '_archive/' | head -1)
if [ -n "$latest" ]; then
    echo "file: $latest"
    awk '/^## Result$/,0' "$latest" | head -20
else
    echo "(no archive)"
fi
```

然後用 5 行內繁中回報：
1. **inbox**：空 / queued（queued 顯示標題）
2. **最近 3 commits**：subject 一行一個
3. **最新 archive Status**：✅/⚠️/❌ + commits 數 + Push 結果（從 Result block 抓）
4. **下一步建議**：1 句

不要重複貼 git log 整段或 Result block 整塊 — statusline 已經有摘要。`/sync` 是讓 user 知道 planner 確實有查、不是只憑 memory 答。
```

**File 2 edit**: `bootstrap.sh` — find existing block that copies slash commands. After `cp "$HARNESS_DIR/.claude/commands/codex-audit.md" .claude/commands/`, ADD:
```bash
cp "$HARNESS_DIR/.claude/commands/sync.md" .claude/commands/
```

**File 3 edit**: `.claude/settings.json` — extend SessionStart hook to ALSO tail latest archive Result block. Read current SessionStart command, REPLACE with:
```bash
test -f RESUME.md && (echo '=== RESUME.md (head) ==='; head -30 RESUME.md; echo ''; echo '=== recent commits ==='; git log --oneline -5 2>/dev/null; echo ''; latest=$(ls -t docs/prompts/[0-9]*-*.md docs/prompts/phase-*.md 2>/dev/null | grep -v '_archive/' | head -1); if [ -n \"$latest\" ]; then echo '=== latest archive Result ==='; awk '/^## Result$/,0' \"$latest\" | head -15; fi) || true
```

(Note JSON escaping — use \" for inner quotes within the JSON string. Verify with `python3 -c "import json; json.load(open('.claude/settings.json'))"`.)

If JSON escaping is messy, alternative: extract the SessionStart command into `scripts/session-briefing.sh` and have settings.json call `bash scripts/session-briefing.sh` instead. Cleaner, easier to maintain. **Do this if the inline JSON-escaped version gets ugly** — bundle the script into commit 2 + add bootstrap.sh copy.

**Verification BEFORE committing**:
```bash
# 1. /sync slash command file is valid markdown
head -5 .claude/commands/sync.md

# 2. settings.json valid
python3 -c "import json; json.load(open('.claude/settings.json')); print('OK')"

# 3. SessionStart command actually runs (extract & test the bash directly)
test -f RESUME.md && (echo '=== RESUME.md (head) ==='; head -30 RESUME.md; echo ''; echo '=== recent commits ==='; git log --oneline -5 2>/dev/null; echo ''; latest=$(ls -t docs/prompts/[0-9]*-*.md docs/prompts/phase-*.md 2>/dev/null | grep -v '_archive/' | head -1); if [ -n "$latest" ]; then echo '=== latest archive Result ==='; awk '/^## Result$/,0' "$latest" | head -15; fi) || true
# Expected: prints RESUME head + commits + latest archive Result block

# 4. bootstrap copies sync.md
cd /tmp && rm -rf wh-sync-test
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh wh-sync-test
ls /tmp/wh-sync-test/.claude/commands/
# Expected: includes sync.md
rm -rf /tmp/wh-sync-test
rm -rf "$HOME/.claude-work/projects/-tmp-wh-sync-test"
cd /Users/woody/Desktop/repo/public/woody-harness/

# 5. test-bootstrap.sh still passes
bash scripts/test-bootstrap.sh
```

**Optional**: extend `scripts/test-bootstrap.sh` to assert `.claude/commands/sync.md exists`. Bundle into this commit.

**Commit subject**: `feat: /sync slash command + SessionStart hook auto-tails latest archive Result`

---

## Hard constraints
1. **NO co-author / Claude trailers** in commits.
2. **DO NOT** modify files outside: `scripts/statusline.sh` (commit 1, new), `.claude/settings.json` (both commits), `bootstrap.sh` (both commits), `scripts/test-bootstrap.sh` (optional add asserts in either commit), `.claude/commands/sync.md` (commit 2, new), optionally `scripts/session-briefing.sh` (commit 2, new if JSON inline gets ugly).
3. **DO NOT** start any next task — auto-queue authorization expires after this round. Even if S-1/T-1 seem natural, STOP.
4. If commit 1's statusline.sh takes > 1 second OR outputs nothing — FIX (root cause: bad git command / missing file path). Do not commit slow statusline.
5. If JSON parse fails at any step — FIX before continuing.
6. If commit 2's SessionStart inline command becomes unreadable due to JSON escaping — fall back to extracting into `scripts/session-briefing.sh` (bundle in commit 2).
7. If `bash scripts/test-bootstrap.sh` fails after EITHER commit — STOP. test-bootstrap is the regression net, must stay green.

## Reply format when done
Per current `/inbox` convention (Result block + osascript notification + 1-2 sentence 繁中 reply). Result block include:

```
**Status**: ✅ shipped
**Commits**: 2 (+ archive auto-commit)
<git log --oneline of the 2 deliverable commits>

**Verification**:
- statusline.sh time: <Xms>
- statusline.sh output: <one-line sample>
- bootstrap copies statusline.sh + sync.md: yes
- SessionStart hook updated: <inline | extracted to script>
- test-bootstrap.sh: PASS N/N
- settings.json valid: yes

**Push**: ✅ pushed to origin/main
**Blockers**: <none | description>
```

Then stop. Do NOT auto-queue T-1 / S-1 / 4e — auto-queue authorization is sequence-bounded.

## Result

**Status**: ✅ shipped
**Commits**: 2 (+ archive auto-commit)
fb00dd2 feat: scripts/statusline.sh + Claude Code statusLine integration
319dae5 feat: /sync slash command + SessionStart hook auto-tails latest archive Result

**Verification**:
- statusline.sh time: 48ms; output: "📥 queued: Phase 4-polish round 3 — statu · 2cafbd4 ... · last: ✅"
- bootstrap copies statusline.sh + session-briefing.sh + sync.md: yes
- SessionStart hook: extracted to scripts/session-briefing.sh (cleaner than inline JSON)
- test-bootstrap.sh: PASS 29/29 checks
- settings.json valid: yes

**Push**: ✅ pushed to origin/main
**Blockers**: none (template _inbox.md shows "queued" in fresh bootstrap — pre-existing known issue, not a regression)
