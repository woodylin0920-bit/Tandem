# Phase 4d — feedback loop (outbox + macOS notification + archive helper)

## Context
- Repo: `/Users/woody/Desktop/repo/public/woody-harness/`
- Phase 1+2+4a+4b+4c all shipped (27 commits public; omni-sense fully purged in 4c).
- Phase 4d adds an event-driven feedback loop so the planner stops manually polling: append `## Result` block to archived prompt files (the "outbox") + macOS notification on `/inbox` completion + manual archive helper for context pruning. Zero deps, zero background process.
- Phase 4e (model + /effort recommendation) follows after — DO NOT touch in this run.

**Architecture choices (locked, do not second-guess)**:
1. **Outbox = appended `## Result` block on the archived prompt file** (NOT a separate `_outbox.md`, NOT inbox status overwrite). Prompt + result paired in one audit-trail file.
2. **Notification trigger = inside `.claude/commands/inbox.md`** (NOT git post-commit hook, NOT bash wrapper). Slash command runs `osascript` via Bash tool as the last step.
3. **Pruning = manual `bash scripts/archive-prompts.sh`** (NOT cron, NOT auto). Idempotent, dry-run supported.

## Working directory
**ALL commands from `/Users/woody/Desktop/repo/public/woody-harness/`.**

Pre-flight:
```bash
cd /Users/woody/Desktop/repo/public/woody-harness/
pwd                         # confirm woody-harness
git status                  # must be clean
git pull --ff-only origin main
ls .claude/                 # baseline: settings.json + commands/ exist
ls scripts/ 2>/dev/null     # baseline: scripts/ may not exist yet
```
If working tree dirty or pull conflicts — STOP and report.

## Commit convention (unchanged)
- Subject only, no co-author trailer.
- Types: `feat`, `fix`, `docs`, `chore`.

---

## Deliverables — 4 atomic commits, in order

### Commit 1 — `.claude/settings.json` permissions allowlist

**Purpose**: pre-authorize the Bash tool calls Sonnet will make for the notification stack so the executor doesn't hit a permission prompt mid-run.

Read current `.claude/settings.json` (created in Phase 4b commit 7) and ADD a `permissions.allow` array. Final file MUST be:

```json
{
  "permissions": {
    "allow": [
      "Bash(osascript:*)",
      "Bash(say:*)",
      "Bash(bash scripts/archive-prompts.sh:*)"
    ]
  },
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "test -f RESUME.md && (echo '=== RESUME.md (head) ==='; head -30 RESUME.md; echo ''; echo '=== recent commits ==='; git log --oneline -5 2>/dev/null) || true"
          }
        ]
      }
    ]
  }
}
```

If the existing SessionStart hook command differs from what's shown above, KEEP the existing command verbatim — only ADD the `permissions` block. Verify:
```bash
python3 -c "import json; json.load(open('.claude/settings.json')); print('OK')"
```

**Commit subject**: `feat: settings.json permissions allowlist for osascript + say + archive`

---

### Commit 2 — `scripts/archive-prompts.sh` (new file)

**Purpose**: manual context pruning. Move dated archive files into `docs/prompts/_archive/<YYYY-MM>/` so `docs/prompts/` stops sprawling. Idempotent. No background process.

Create dir if missing: `mkdir -p scripts`

**File**: `scripts/archive-prompts.sh`
```bash
#!/usr/bin/env bash
# Archive dated prompts under docs/prompts/_archive/<YYYY-MM>/
# Usage: bash scripts/archive-prompts.sh [--dry-run]
set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

cd "$(git rev-parse --show-toplevel)" || { echo "not in a git repo" >&2; exit 1; }

PROMPTS_DIR="docs/prompts"
ARCHIVE_ROOT="$PROMPTS_DIR/_archive"
shopt -s nullglob

moved=0

# Dated archives: 2026-04-28-foo.md
for f in "$PROMPTS_DIR"/[0-9][0-9][0-9][0-9]-*.md; do
    base=$(basename "$f")
    yyyymm=$(echo "$base" | grep -oE '^[0-9]{4}-[0-9]{2}')
    [ -z "$yyyymm" ] && continue

    target_dir="$ARCHIVE_ROOT/$yyyymm"
    target="$target_dir/$base"

    if [ "$DRY_RUN" = 1 ]; then
        echo "DRY: $base -> _archive/$yyyymm/"
    else
        mkdir -p "$target_dir"
        git mv "$f" "$target" 2>/dev/null || mv "$f" "$target"
        echo "moved $base -> _archive/$yyyymm/"
    fi
    moved=$((moved + 1))
done

# Legacy "phase-*.md" naming (pre-2026-04-28)
for f in "$PROMPTS_DIR"/phase-*.md; do
    base=$(basename "$f")
    target_dir="$ARCHIVE_ROOT/legacy"
    target="$target_dir/$base"

    if [ "$DRY_RUN" = 1 ]; then
        echo "DRY: $base -> _archive/legacy/"
    else
        mkdir -p "$target_dir"
        git mv "$f" "$target" 2>/dev/null || mv "$f" "$target"
        echo "moved $base -> _archive/legacy/"
    fi
    moved=$((moved + 1))
done

if [ "$moved" = 0 ]; then
    echo "nothing to archive."
elif [ "$DRY_RUN" = 0 ]; then
    echo ""
    echo "$moved file(s) moved. Review with 'git status', then commit:"
    echo "  git commit -m 'chore: archive prompts to _archive/'"
fi
```

**Verification**:
```bash
bash scripts/archive-prompts.sh --dry-run
```
Expected: lists current `docs/prompts/*.md` files matching the patterns (Phase 4c-archived files + any legacy `phase-*.md`). DO NOT actually run without --dry-run in this commit — leave moves as user discretion.

**Commit subject**: `feat: scripts/archive-prompts.sh — manual prompt archive helper`

---

### Commit 3 — `bootstrap.sh` copies archive script to new projects

**Purpose**: bootstrapped projects get the archive helper too.

Read current `bootstrap.sh`. Find the block that copies slash commands / settings (post-Phase-4b state, around line 26-32). After the LAST `cp ... .claude/...` line, INSERT:

```bash

# Copy archive helper
mkdir -p scripts
cp "$HARNESS_DIR/scripts/archive-prompts.sh" scripts/archive-prompts.sh
```

(Do NOT chmod +x — invocation via `bash scripts/...` matches existing convention; chmod adds VCS noise.)

**Verification**:
```bash
cd /tmp && rm -rf wh-test
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh wh-test
ls /tmp/wh-test/scripts/
bash /tmp/wh-test/scripts/archive-prompts.sh --dry-run
cd /Users/woody/Desktop/repo/public/woody-harness/
```
Expected: `archive-prompts.sh` listed; dry-run prints `nothing to archive.` (fresh project). If anything diverges, FIX bootstrap.sh and re-test before committing.

**Commit subject**: `feat: bootstrap.sh copies archive-prompts.sh to new projects`

---

### Commit 4 — full rewrite of `.claude/commands/inbox.md` (Result block + notification)

**Purpose**: encode the feedback loop in the slash command itself so every future `/inbox` execution auto-appends a Result block AND fires a macOS notification — no per-prompt boilerplate, no manual polling.

**File**: `.claude/commands/inbox.md` — REPLACE entire content with:

```markdown
---
description: 讀 docs/prompts/_inbox.md 的 prompt 開工，完成後 append Result + 通知
---

讀取 `docs/prompts/_inbox.md` 的完整內容，把它當作這次對話的 prompt 開始執行。

## 執行流程

1. `cat docs/prompts/_inbox.md` 看完整 prompt
2. 完全照 prompt 開工（不要二次推理 prompt 的決策，那些已由規劃端鎖定）
3. 全部 commit + push 完成後（或卡住時），執行**收尾流程**：

   a. 把 `docs/prompts/_inbox.md` 的內容**搬移**到 `docs/prompts/<YYYY-MM-DD-descriptive-slug>.md`
   b. 在搬移後的檔案**末尾** append 一個 `## Result` 區塊：

      ```markdown
      ## Result

      **Status**: ✅ shipped | ⚠️ blocked | ❌ failed
      **Commits**: <count>
      <git log --oneline of new commits this session, one per line>

      **Verification**: <1-2 line test/smoke/dry-run output>
      **Push**: ✅ pushed to origin/main | ❌ <reason>
      **Blockers**: <description, or "none">
      ```

   c. 清空 `docs/prompts/_inbox.md` 為單一 newline
   d. 把 a/b/c 全部納入**最後一個 commit**（subject: `chore: archive <slug> inbox prompt + result`）並 push

4. **最後**：透過 Bash tool 觸發 macOS 通知：

   - **成功**：
     ```
     osascript -e 'display notification "✅ <count> commits — <slug>" with title "woody-harness · inbox done" sound name "Glass"'
     ```
   - **卡住 / 失敗**：
     ```
     osascript -e 'display notification "⚠️ blocked — see _inbox.md" with title "woody-harness · inbox blocked" sound name "Funk"'
     say -v Mei-Jia "卡住了" 2>/dev/null || true
     ```

5. 回報給使用者：1-2 句繁中，包含 archive 檔路徑 + status，不再重複貼整段 git log（已在 archive 裡）。

## 邊界情況

- `_inbox.md` 空的或內容不像 prompt：跟使用者確認，**不要**觸發通知或建立 archive 檔。
- 中途卡住（hard constraint 違反 / test fail / push reject）：照 prompt 的 STOP 規則停下，**仍然執行 3b（Status: ⚠️ blocked）+ 3c + 4 通知**，使用者要收到訊息才知道要看 inbox。
- `osascript` / `say` 在非 macOS 環境會失敗 — 用 `2>/dev/null || true` 包起來，不要因此中斷流程。
```

**Note for THIS run specifically**: the executor for THIS Phase 4d run is following the OLD `inbox.md` convention (loaded at session start). After commit 4 ships, the new convention applies to FUTURE `/inbox` invocations.

**However, as a courtesy** — fire the notification at the end of THIS run too, so user gets first taste of the new convention. After all 4 commits + push, run:
```
osascript -e 'display notification "✅ 4 commits — Phase 4d feedback loop" with title "woody-harness · inbox done" sound name "Glass"'
```

**Commit subject**: `feat: /inbox slash command — append Result block + macOS notification (feedback loop)`

---

## After all 4 commits
```bash
git log --oneline -10
git push origin main
git status
bash scripts/archive-prompts.sh --dry-run
osascript -e 'display notification "✅ 4 commits — Phase 4d feedback loop" with title "woody-harness · inbox done" sound name "Glass"'
```

## Hard constraints
1. **NO co-author / Claude trailers** in commits.
2. **DO NOT** modify files outside: `.claude/settings.json` (commit 1), `scripts/archive-prompts.sh` (commit 2, new), `bootstrap.sh` (commit 3), `.claude/commands/inbox.md` (commit 4).
3. **DO NOT** run `bash scripts/archive-prompts.sh` without `--dry-run` in this run — leave actual archive moves as user discretion.
4. **DO NOT** start Phase 4e (model + /effort recommendation) — separate prompt.
5. Settings.json must remain valid JSON after every edit — verify with `python3 -c "import json; json.load(open('.claude/settings.json'))"`.
6. If commit 3's bootstrap dry-run fails, STOP and report — do not commit broken bootstrap.
7. The slash command rewrite in commit 4 fully REPLACES old content; do not try to merge / preserve old text beyond what's specified.

## Reply format when done
```
✅ Phase 4d shipped — 4 commits + push + courtesy notification fired

<git log --oneline -8>

JSON valid: yes
Bootstrap dry-run: <pass | fail>
Archive dry-run output: <one-liner>
Notification fired: <yes — sound played | no — reason>

Ready for Phase 4e (model + /effort recommendation system).
```

Then stop. Do NOT proactively start 4e.

## Result

**Status**: ✅ shipped
**Commits**: 4
4071bc1 feat: settings.json permissions allowlist for osascript + say + archive
7933ce1 feat: scripts/archive-prompts.sh — manual prompt archive helper
60bcd5d feat: bootstrap.sh copies archive-prompts.sh to new projects
7cd153c feat: /inbox slash command — append Result block + macOS notification (feedback loop)

**Verification**: `python3 -c "import json; json.load(open('.claude/settings.json'))"` → OK; bootstrap dry-run → nothing to archive. (fresh project); `bash scripts/archive-prompts.sh --dry-run` → 2 legacy files listed
**Push**: ✅ pushed to origin/main
**Blockers**: none
