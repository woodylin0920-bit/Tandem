# T-1a-β: memory.sh promote — interactive migration helper

## Goal

收尾 T-1a：加 `scripts/memory.sh promote` 互動 helper，讓 user 把既有 project memory 逐條決定 promote/keep/delete。**這輪只 ship 工具 + 驗證；不在 Sonnet 內跑 promote 改 woody-harness 自己的 memory** — 那是 user 自己 interactively 跑的事。

## Execution profile

- model: sonnet
- effort: medium（一個 subcommand + 互動 + 邊界處理）
- 3 commits（promote subcommand / docs / archive）

## Background context

T-1a-α 已 shipped：shared layer 在 `~/.claude-work/_shared/memory/`、`memory.sh sync` 把 shared symlink 進 project、bootstrap 第一次 seed shared。

woody-harness 自己的 memory dir（17 條）目前**全部都還是 project-local real file**，沒被 T-1a-α 動過。需要 helper 讓 user 決定每條 → shared / 留 project / 刪。

「互動」意思是 helper 對每條 memory 印出資訊後 `read` 一個字元（p/k/d/s/q），sonnet 自己**不能**做這個互動（它是執行者不是 user）— 所以 sonnet 的責任：
- 實作 helper（commit 1）
- 用 mktemp 假 project 跑驗證（測 promote / keep / delete / quit / 衝突 / MEMORY.md 邊界處理）
- 寫文件（commit 2）
- archive（commit 3）

User 之後在自己 terminal 跑 `bash scripts/memory.sh promote` interactively。

---

## Commit 1: `feat: scripts/memory.sh promote — interactive migration to shared layer`

修改 `scripts/memory.sh` 加 `promote` subcommand。

### A. CLI 行為

```bash
bash scripts/memory.sh promote
```

從當前 git repo root 跑。

**Pre-flight**：
- Project memory dir 存在 → 否則 error
- Shared memory dir 存在 → 否則 error: "no shared layer at $shared_mem — run bootstrap.sh on a new project to seed it"
- Project MEMORY.md 有 markers（BEGIN/END project-local）→ 否則 error: "project MEMORY.md missing T-1a-α markers — run 'bash scripts/memory.sh sync' first"

**主迴圈**：

掃 project memory dir 所有 **real file**（非 symlink、非 MEMORY.md），對每個依序：

1. 印該檔資訊：
   ```
   ---
   [3/12] feedback_terse_zh.md
     name: terse Mandarin updates
     description: reply in 繁中, 1-2 sentences...
     type: feedback
   
   Action? [p]romote / [k]eep / [d]elete / [s]kip / [q]uit:
   ```
   
   `name`/`description`/`type` 從 frontmatter parse（awk / sed 都行）。如 frontmatter 缺 → 印 `(no frontmatter)` 不要 abort。

2. `read -n 1 ans` 收一個字元，依 ans 分支：

   - **`p` promote** → 動作：
     1. 衝突檢查：if `$shared_mem/$name` 已存在（且非當前要 promote 的同個 inode）：
        ```
        ⚠️  shared already has 'feedback_terse_zh.md':
            shared name: terse Mandarin updates (frontmatter from existing shared file)
            local name:  terse Mandarin updates
        Choose: [o]verwrite shared / [r]ename local / [c]ancel:
        ```
        - `o`: 繼續流程（覆蓋 shared）
        - `r`: 提示 new name `read -p "new name (without .md): " new`，更新 file → `${new}.md`，繼續用新名 promote
        - `c`: skip 此檔，回主迴圈下一個
     2. `mv "$proj_mem/$name" "$shared_mem/$name"`
     3. 從 project MEMORY.md `<!-- BEGIN project-local -->` 段移除該檔對應 entry（用 sed match `[$frontmatter_name]($name)` 或 fallback to `($name)` pattern）
     4. 加 entry 到 shared MEMORY.md（從 frontmatter description 組）：
        `- [$frontmatter_name]($name) — $frontmatter_description`
     5. 跑 `bash scripts/memory.sh sync >/dev/null 2>&1` 重建 symlink + 重生 project MEMORY.md shared section
     6. 印 `  → promoted to shared.`
     7. counter `n_promoted++`

   - **`k` keep** → 不動，印 `  → kept project-local.`，counter `n_kept++`

   - **`d` delete** →
     1. 二次確認：`Confirm permanent delete of $name? [y/N]: `（capital N，預設拒絕）
     2. 如非 `y`/`Y`：printf "  → cancelled.\n"，當 skip 處理
     3. 如 yes：`rm "$proj_mem/$name"`，從 project MEMORY.md project-local section 移除 entry，印 `  → deleted.`，counter `n_deleted++`

   - **`s` skip** → 不動，印 `  → skipped (will appear next run).`，counter `n_skipped++`

   - **`q` quit** → break 迴圈，跳到 summary

   - **其他**: 印 `(invalid; expected p/k/d/s/q)`，重複該檔 prompt

3. 迴圈跑完或 `q` quit 後，印 summary：
   ```
   === Summary ===
   Promoted to shared: <n_promoted>
   Kept project-local: <n_kept>
   Deleted:            <n_deleted>
   Skipped:            <n_skipped>
   
   Run 'bash scripts/memory.sh list' to see current state.
   ```

### B. Frontmatter parser

最簡 awk pattern（在 `--- ... ---` block 內找 `name:` `description:` `type:`）:
```bash
parse_field() {
    awk -v field="$1" '
        /^---$/ {fm++; next}
        fm==1 && $0 ~ "^"field":" {sub("^"field":[ \t]*", ""); print; exit}
    ' "$2"
}

frontmatter_name=$(parse_field name "$file")
frontmatter_description=$(parse_field description "$file")
frontmatter_type=$(parse_field type "$file")
```

### C. MEMORY.md 編輯邊界

兩個 section 用 marker 包起：
```
<!-- BEGIN shared (auto-managed by scripts/memory.sh sync — do not edit between markers) -->
...
<!-- END shared -->

<!-- BEGIN project-local (you can edit this section freely) -->
...
<!-- END project-local -->
```

**Promote/Delete 只動 project-local section**（shared section 由 sync 維護）。用 awk pattern 寫一個 helper:

```bash
remove_entry_from_project_local_section() {
    local memory_md="$1"
    local entry_pattern="$2"   # e.g. "($name)"
    local tmp=$(mktemp)
    awk -v pat="$entry_pattern" '
        /<!-- BEGIN project-local/ {in_local=1; print; next}
        /<!-- END project-local/ {in_local=0; print; next}
        in_local && index($0, pat) > 0 {next}
        {print}
    ' "$memory_md" > "$tmp"
    mv "$tmp" "$memory_md"
}
```

### D. Verification（commit 前自己跑）

用 mktemp 假 project，pipe stdin 模擬互動（不能真互動 sonnet 跑）。

```bash
HARNESS=$(pwd)
TMP=$(mktemp -d -t wh-promote-XXXXXX)
cd "$TMP"

# 假 project
mkdir -p "$TMP/proj/.git"
cd "$TMP/proj"
git init -q

# 假 shared 跟 project memory dir
SLUG=$(echo "$TMP/proj" | sed 's|/|-|g')
PMEM="$HOME/.claude-work/projects/$SLUG/memory"
SMEM="$HOME/.claude-work/_shared/memory"
mkdir -p "$PMEM" "$SMEM"

# Shared seed（一條 dummy）
cat > "$SMEM/MEMORY.md" <<'EOF'
- [pre-existing shared](pre_shared.md) — placeholder for conflict test
EOF
cat > "$SMEM/pre_shared.md" <<'EOF'
---
name: pre-existing shared
description: placeholder for conflict test
type: feedback
---
EOF

# Project memory: 4 條 real files
cat > "$PMEM/feedback_one.md" <<'EOF'
---
name: feedback one
description: should promote
type: feedback
---
content one
EOF
cat > "$PMEM/feedback_two.md" <<'EOF'
---
name: feedback two
description: should keep
type: feedback
---
content two
EOF
cat > "$PMEM/feedback_three.md" <<'EOF'
---
name: feedback three
description: should delete
type: feedback
---
content three
EOF
cat > "$PMEM/pre_shared.md" <<'EOF'
---
name: pre-existing shared (conflict)
description: should trigger conflict prompt
type: feedback
---
EOF

cat > "$PMEM/MEMORY.md" <<'EOF'
<!-- BEGIN shared (auto-managed by scripts/memory.sh sync — do not edit between markers) -->
- [pre-existing shared](pre_shared.md) — placeholder for conflict test
<!-- END shared -->

<!-- BEGIN project-local (you can edit this section freely) -->
- [feedback one](feedback_one.md) — should promote
- [feedback two](feedback_two.md) — should keep
- [feedback three](feedback_three.md) — should delete
- [pre-existing shared (conflict)](pre_shared.md) — should trigger conflict prompt
<!-- END project-local -->
EOF

# Pipe answers: p (promote feedback_one), k (keep feedback_two), d + y (delete feedback_three), c (cancel pre_shared conflict)
# Order depends on iteration order — sonnet your script must do `ls $PMEM/*.md | sort` predictably
# Expected iteration order (alphabetical): feedback_one, feedback_three, feedback_two, pre_shared
# Adjust answer order accordingly: p, d, y, k, c
printf 'p\nd\ny\nk\nc\n' | bash "$HARNESS/scripts/memory.sh" promote 2>&1 | tee /tmp/wh-promote-out.txt

# Assertions
test -f "$SMEM/feedback_one.md" && echo "PASS: feedback_one promoted to shared" || { echo "FAIL"; exit 1; }
test ! -f "$PMEM/feedback_one.md" || test -L "$PMEM/feedback_one.md" && echo "PASS: feedback_one removed from project (or symlink)" || { echo "FAIL"; exit 1; }
test -f "$PMEM/feedback_two.md" && ! test -L "$PMEM/feedback_two.md" && echo "PASS: feedback_two kept as real file" || { echo "FAIL"; exit 1; }
test ! -f "$PMEM/feedback_three.md" && echo "PASS: feedback_three deleted" || { echo "FAIL"; exit 1; }
test -f "$PMEM/pre_shared.md" && echo "PASS: pre_shared conflict cancelled (kept project)" || { echo "FAIL"; exit 1; }

# Shared MEMORY.md should now have feedback_one entry
grep -q "feedback_one" "$SMEM/MEMORY.md" && echo "PASS: shared MEMORY.md has feedback_one"
# Project MEMORY.md project-local section should not have feedback_one (now in shared)
awk '/<!-- BEGIN project-local/,/<!-- END project-local/' "$PMEM/MEMORY.md" | grep -q "feedback_one" && { echo "FAIL: feedback_one still in project-local"; exit 1; } || echo "PASS: feedback_one out of project-local"
# Project MEMORY.md project-local section should NOT have feedback_three (deleted)
awk '/<!-- BEGIN project-local/,/<!-- END project-local/' "$PMEM/MEMORY.md" | grep -q "feedback_three" && { echo "FAIL: feedback_three still listed"; exit 1; } || echo "PASS: feedback_three removed from MEMORY.md"

# Test quit mid-iteration: setup another project, just quit immediately
# (omitted for brevity; sonnet you can add if you have time)

# 清理
cd "$HARNESS"
rm -rf "$TMP" "$HOME/.claude-work/projects/$SLUG" "$SMEM"
rm -f /tmp/wh-promote-out.txt
```

要全 PASS 才 commit 1。

> **重要**：verification 結束務必清掉 mktemp 的 project memory dir + `~/.claude-work/_shared/memory/`（測試用的，不是 user 真的）。User 自己的 woody-harness memory dir + 任何已存在的 `_shared/` 都**不要碰**。

---

## Commit 2: `docs: SHARED_MEMORY.md migration section + REFERENCE.md promote row + CHANGELOG`

### A. `docs/SHARED_MEMORY.md` 改 — 找 "Migrating existing project memory to shared" 那段（T-1a-α 留的占位）

替換內容：

```markdown
### Migrating existing project memory to shared

Use the interactive `promote` helper:

```bash
bash scripts/memory.sh promote
```

It walks through every real file in your project memory dir and prompts per file:

```
[3/12] feedback_terse_zh.md
  name: terse Mandarin updates
  description: reply in 繁中, 1-2 sentences...
  type: feedback

Action? [p]romote / [k]eep / [d]elete / [s]kip / [q]uit:
```

- **`p` promote** — moves the file to `~/.claude-work/_shared/memory/`, adds an entry to shared `MEMORY.md`, and re-syncs the project (the file becomes a symlink in your project dir, available to *every* project that sync's).
- **`k` keep** — leaves the file as project-local.
- **`d` delete** — permanent delete (asks for `y` confirmation).
- **`s` skip** — decide later; the file stays untouched and appears again on next run.
- **`q` quit** — stops iteration; whatever's been promoted/kept/deleted so far is preserved.

If the shared layer already has a same-named file, `promote` asks: overwrite shared / rename local / cancel.

After running, your project MEMORY.md is updated automatically — promoted entries appear in the `<!-- BEGIN shared -->` section, deleted entries are removed.
```

### B. `docs/REFERENCE.md` 改 — `memory.sh` 表格加一行

在現有 `memory.sh sync` 行下面加：
```
| | `bash scripts/memory.sh promote` | Interactive helper to migrate project memory entries to shared layer (promote/keep/delete) |
```

### C. CHANGELOG.md `[Unreleased]` 加（合併到既有 `### Added` 段）

```markdown
- `scripts/memory.sh promote` — interactive migration helper for moving existing project memory entries into the shared layer (T-1a-β; completes the cross-project shared memory feature).
```

### D. Verification

```bash
grep -q "promote" docs/SHARED_MEMORY.md && echo "PASS: SHARED_MEMORY.md has promote section" || { echo "FAIL"; exit 1; }
grep -q "memory.sh promote" docs/REFERENCE.md && echo "PASS: REFERENCE row added" || { echo "FAIL"; exit 1; }
grep -q "memory.sh promote" CHANGELOG.md && echo "PASS: CHANGELOG entry"
```

---

## Commit 3 (auto): archive

跑 `bash scripts/archive-prompts.sh` 把 `docs/prompts/_inbox.md` 內容歸檔成 `docs/prompts/<date>-t1a-beta-promote-helper.md` 並補 Result block + 清空 _inbox.md。

---

## Hard rules

1. **DO NOT** modify woody-harness's own memory dir（`~/.claude-work/projects/-Users-woody-Desktop-repo-public-woody-harness/memory/`）。本輪只 ship 工具，**不**跑 promote on 真實 user memory — 那是 user 自己 interactively 做的事。
2. **DO NOT** modify files outside這些：`scripts/memory.sh`（commit 1）、`docs/SHARED_MEMORY.md`（commit 2）、`docs/REFERENCE.md`（commit 2）、`CHANGELOG.md`（commit 2）。
3. **DO NOT** auto-queue 下一輪。跑完 archive 後 STOP。
4. 任何 verification step FAIL → STOP + 印錯誤 + 不 commit broken state。
5. 驗證使用的 mktemp project + 對應 `~/.claude-work/projects/<slug>/`、測試用的 `~/.claude-work/_shared/memory/` 在 verification 結束務必清乾淨。
6. 不要動 T-1a-α 的 sync 邏輯（promote 內部呼叫 sync 是 OK，但不要重寫 sync）。
7. macOS BSD sed 用 `sed -i ''`（per env_paths memory）。
8. 通知：成功 → `afplay /System/Library/Sounds/Glass.aiff` + `osascript -e 'display notification "T-1a-β shipped — run promote when ready" with title "woody-harness"'`；失敗 → `say -v Mei-Jia "卡住了"`（per macOS notification memory）。

## Result block convention

跑完最後 append 到本檔案結尾：

```markdown
## Result

**Status**: ✅ shipped | ❌ blocked
**Commits**: 3 (incl. archive)
<sha> feat: scripts/memory.sh promote — interactive migration to shared layer
<sha> docs: SHARED_MEMORY.md migration section + REFERENCE.md promote row + CHANGELOG
<sha> chore: archive t1a-beta-promote-helper inbox prompt + result

**Verification**:
- promote test 1: file promoted (real → shared, project gets symlink): PASS / FAIL
- promote test 2: file kept (real file untouched): PASS / FAIL
- promote test 3: file deleted (with y confirmation): PASS / FAIL
- promote test 4: conflict cancel preserves project file: PASS / FAIL
- shared MEMORY.md updated with promoted entry: PASS / FAIL
- project MEMORY.md project-local section cleaned of promoted/deleted entries: PASS / FAIL
- mktemp + ~/.claude-work test artifacts cleaned: PASS / FAIL
- woody-harness own memory dir untouched: PASS / FAIL

**Push**: ✅ pushed to origin/main / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ✅ shipped
**Commits**: 3 (incl. archive)
e8062b5 feat: scripts/memory.sh promote — interactive migration to shared layer
9c99ea1 docs: SHARED_MEMORY.md migration section + REFERENCE.md promote row + CHANGELOG
<archive-sha> chore: archive t1a-beta-promote-helper inbox prompt + result

**Verification**:
- promote test 1: file promoted (real → shared, project gets symlink): PASS
- promote test 2: file kept (real file untouched): PASS
- promote test 3: file deleted (with y confirmation): PASS
- promote test 4: conflict cancel preserves project file: PASS
- shared MEMORY.md updated with promoted entry: PASS
- project MEMORY.md project-local section cleaned of promoted/deleted entries: PASS
- mktemp + ~/.claude-work test artifacts cleaned: PASS
- woody-harness own memory dir untouched: PASS

**Push**: ✅ pushed to origin/main
**Blockers**: none
