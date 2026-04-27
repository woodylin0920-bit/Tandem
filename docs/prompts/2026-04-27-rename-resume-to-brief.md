# Rename `/resume` → `/brief` slash command (avoid Claude Code built-in collision)

## Goal

Claude Code 內建有 `/resume`（resume previous conversation），woody-harness 的 `/resume`（print briefing）撞名 — 下拉選單會列兩個，user 要靠 description 分辨。改名 woody-harness 那個為 `/brief`（呼應 `session-briefing.sh`）。

## Execution profile

- model: sonnet
- effort: small（純 rename + 多檔字串替換 + 一條 changelog entry）
- 2 commits（rename / archive）

## Background context

- Claude Code 內建 `/resume` = "Resume a previous conversation"
- woody-harness 的 `/resume` = print RESUME.md head + commits + handoff memory（Phase 4b 加的）
- User 拍板改名為 **`/brief`**（不選 /recap, /status, /whereami）
- 影響面：1 個 .md 檔重命名 + bootstrap.sh 多處 + test-bootstrap.sh + 多個 docs 提及
- **歷史性記錄不改**（[0.4.0] / [0.4.1] CHANGELOG entries 已 ship 不動，那是 history）

---

## Commit 1: `feat: rename /resume → /brief slash command (avoid Claude Code built-in collision)`

### A. Rename the file

```bash
git mv .claude/commands/resume.md .claude/commands/brief.md
```

不要 `cp` 然後 `rm` — 用 `git mv` 保留 history。

### B. 改 `.claude/commands/brief.md` 自己內容

打開新檔（已重命名），把裡面 frontmatter 跟描述內任何 `/resume` / "resume" 指代 slash command 名的字眼改成 `/brief`。**檔名 `RESUME.md`（user 內容檔）不要改**，只改 slash command 名稱本身。

例如如果裡面有：
```
description: 印當前進度 briefing — RESUME.md 前 30 行 + 最近 commits + handoff memory
```
保留 — 這描述提到的 `RESUME.md` 是檔名，不是 command 名。

但如果有：
```
# /resume
This command resumes ...
```
改成：
```
# /brief
This command briefs ...
```

> 用 `grep -n "resume" .claude/commands/brief.md` 確認所有出現處後逐個判斷：是「指 slash command `/resume`」→ 改 `/brief`；是「指檔名 `RESUME.md`」→ 留。

### C. `bootstrap.sh` 改 2 處

**位置 1**：`FRAMEWORK_FILES` 陣列第 17 行附近：
```bash
".claude/commands/resume.md|.claude/commands/resume.md"
```
改成：
```bash
".claude/commands/brief.md|.claude/commands/brief.md"
```

**位置 2**：第 481 行附近的 `cp` 呼叫：
```bash
cp "$HARNESS_DIR/.claude/commands/resume.md" .claude/commands/
```
改成：
```bash
cp "$HARNESS_DIR/.claude/commands/brief.md" .claude/commands/
```

### D. `scripts/test-bootstrap.sh` 改 1 處（line 46 附近）

```bash
assert ".claude/commands/resume.md exists" test -f .claude/commands/resume.md
```
改成：
```bash
assert ".claude/commands/brief.md exists" test -f .claude/commands/brief.md
```

### E. 改 docs（多檔字串替換）

**`docs/REFERENCE.md`**：line 20 附近的表格：
```
| `/resume` | Print RESUME.md head + recent commits + handoff memory |
```
改成：
```
| `/brief` | Print RESUME.md head + recent commits + handoff memory |
```

**`docs/MEMORY_SYSTEM.md`**：lines 138 + 140
- "type `/resume` in any Claude Code session" → "type `/brief` in any Claude Code session"
- "See `.claude/commands/resume.md`" → "See `.claude/commands/brief.md`"

**`docs/UPGRADE.md`**：lines 56 + 74
- 檔案清單中 `.claude/commands/resume.md` → `.claude/commands/brief.md`
- 例句 "New slash commands shipped (`/sync`, `/resume`, etc.)" → "New slash commands shipped (`/sync`, `/brief`, etc.)"

**`docs/REMOVE.md`**：line 64
- 檔案清單中 `.claude/commands/resume.md` → `.claude/commands/brief.md`

**`docs/TUTORIAL.md`**：lines 58 + 296
- ASCII tree comment "# /resume slash command" → "# /brief slash command"
- "try `/resume` in your executor session" → "try `/brief` in your executor session"

**`docs/TROUBLESHOOTING.md`**：lines 215-226 整段「`/resume` slash command not found」entry
- 標題 `### /resume slash command not found` → `### /brief slash command not found`
- 內文 `/resume` mentions → `/brief`
- 修復步驟的檔名 `resume.md` → `brief.md`
- **加註**（在這個 entry 結尾）：
  ```
  > **Note**: This command was renamed from `/resume` to `/brief` in v0.4.2 to avoid colliding with Claude Code's built-in `/resume` (resume previous conversation). If you bootstrapped before v0.4.2, the upgrade flow will install `brief.md`; you can manually `git rm .claude/commands/resume.md` to clean up the old name.
  ```

**`RESUME.md`（root）**：line 56
- "MEMORY_SYSTEM, /resume slash, SessionStart hook" → "MEMORY_SYSTEM, /brief slash (originally /resume), SessionStart hook"

> 我（planner）會自己 update memory 提及 `/resume` 的地方，**你不要動 memory dir**（per hard rules）。

### F. CHANGELOG entry（在 [Unreleased] 段下加）

```markdown
## [Unreleased]

### Changed
- Renamed `/resume` slash command to `/brief` to avoid colliding with Claude Code's built-in `/resume` (resume previous conversation). Existing bootstrapped projects: upgrade flow installs `brief.md`; orphan `resume.md` can be manually removed. See `docs/TROUBLESHOOTING.md` "`/brief` slash command not found".
```

> 原本的空 `[Unreleased]` 段（v0.4.1 release 後留的占位）就用這個內容填。**不要動已 ship 的 [0.4.1] / [0.4.0] / [0.2.0] / [0.1.0] entries**。

---

## Verification（commit 前自己跑）

```bash
# 1. 新檔在、舊檔不在
test -f .claude/commands/brief.md && echo "PASS: brief.md exists" || { echo "FAIL"; exit 1; }
test ! -f .claude/commands/resume.md && echo "PASS: resume.md removed" || { echo "FAIL: resume.md still exists"; exit 1; }

# 2. bootstrap.sh 沒殘留 .claude/commands/resume.md
! grep -q "resume.md" bootstrap.sh && echo "PASS: bootstrap.sh clean" || { echo "FAIL: bootstrap.sh still mentions resume.md"; exit 1; }

# 3. test-bootstrap.sh 沒殘留
! grep -q "resume.md" scripts/test-bootstrap.sh && echo "PASS: test-bootstrap.sh clean" || { echo "FAIL"; exit 1; }

# 4. bootstrap.sh syntax 沒壞
bash -n bootstrap.sh && echo "PASS: bash -n bootstrap.sh" || { echo "FAIL"; exit 1; }

# 5. test-bootstrap.sh 全綠（驗證 brief.md assertion 真的對）
bash scripts/test-bootstrap.sh && echo "PASS: test-bootstrap 32/32" || { echo "FAIL"; exit 1; }

# 6. CHANGELOG [Unreleased] 有內容
awk '/^## \[Unreleased\]/,/^## \[/' CHANGELOG.md | grep -q "brief" && echo "PASS: CHANGELOG entry present" || { echo "FAIL"; exit 1; }

# 7. docs 沒殘留 /resume slash command 提及（resume.md 這字串如還在 TROUBLESHOOTING 提到「舊名」是合法的，所以 grep 用 `/resume` 加空格邊界）
remaining=$(grep -rn "/resume\b" docs/ README.md RESUME.md 2>/dev/null | grep -v "_archive\|prompts/" | grep -v "originally /resume\|renamed from \`/resume\`" || true)
if [ -z "$remaining" ]; then echo "PASS: no orphan /resume mentions"; else echo "FAIL: orphans:"; echo "$remaining"; exit 1; fi
```

> Verification 7 的 grep 把「合法保留的歷史提及」（`originally /resume`、`renamed from \`/resume\``）排除。如果你發現 docs 裡還有其他**合法**保留 `/resume` 的地方，告訴 user 不要 fail，但要在 Result block 列出來。

要全 PASS 才 commit 1。

---

## Commit 2 (auto): archive

跑 `bash scripts/archive-prompts.sh` 把 `docs/prompts/_inbox.md` 內容歸檔成 `docs/prompts/<date>-rename-resume-to-brief.md` 並補 Result block + 清空 _inbox.md。

---

## Hard rules

1. **DO NOT** 動 memory dir（`~/.claude-work/projects/*/memory/`）。Planner 自己會處理 memory。
2. **DO NOT** 動歷史 CHANGELOG entries（`[0.4.0]`, `[0.4.1]`, `[0.2.0]`, `[0.1.0]`）— history 不改寫。
3. **DO NOT** 動 archived prompts（`docs/prompts/[0-9]*-*.md`, `phase-*.md`）— 那些是 historical record。
4. **DO NOT** auto-queue 下一輪。跑完 archive 後 STOP。
5. 任何驗證 step 失敗 → STOP + 印錯誤 + 不要 commit broken state。
6. 用 `git mv`（不是 `cp` + `rm`）保留 history。
7. macOS BSD sed 用 `sed -i ''`（per env_paths memory）。
8. 通知：成功 → `afplay /System/Library/Sounds/Glass.aiff` + `osascript -e 'display notification "rename done" with title "woody-harness"'`；失敗 → `say -v Mei-Jia "卡住了"`（per macOS notification memory）。

## Result block convention

跑完最後 append 到本檔案結尾：

```markdown
## Result

**Status**: ✅ shipped | ❌ blocked
**Commits**: 2 (incl. archive)
<sha> feat: rename /resume → /brief slash command (avoid Claude Code built-in collision)
<sha> chore: archive rename-resume-to-brief inbox prompt + result

**Verification**:
- brief.md exists, resume.md removed: PASS / FAIL
- bootstrap.sh clean: PASS / FAIL
- test-bootstrap.sh clean: PASS / FAIL
- bash -n bootstrap.sh: PASS / FAIL
- test-bootstrap.sh 32/32: PASS / FAIL
- CHANGELOG [Unreleased] entry: PASS / FAIL
- No orphan /resume mentions in docs: PASS / FAIL (with allowed-exception list)

**Allowed-exception /resume mentions** (legal historical references, not bugs):
- <list any>

**Push**: ✅ pushed to origin/main / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ✅ shipped
**Commits**: 2 (incl. archive)
a6c6204 feat: rename /resume → /brief slash command (avoid Claude Code built-in collision)
<archive-sha> chore: archive rename-resume-to-brief inbox prompt + result

**Verification**:
- brief.md exists, resume.md removed: PASS
- bootstrap.sh clean: PASS
- test-bootstrap.sh clean: PASS
- bash -n bootstrap.sh: PASS
- test-bootstrap.sh 32/32: PASS
- CHANGELOG [Unreleased] entry: PASS
- No orphan /resume mentions in docs: PASS

**Allowed-exception /resume mentions** (legal historical references, not bugs):
- none

**Push**: ✅ pushed to origin/main
**Blockers**: none
