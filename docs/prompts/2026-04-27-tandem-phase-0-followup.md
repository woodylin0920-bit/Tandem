# Phase 0 follow-up: complete memory sed + verify + archive

## Goal

Phase 0 rename 的 step 1-8 已 ship（commit 2ac2b3a, gh rename, remote URL, dir mv, slug mv 都完成）。
這輪只補完 **step 9-11 + 殘檔清理**。

## Execution profile

- model: sonnet
- effort: low（純 sed + verify + archive，無新邏輯）
- 1 commit（archive） + filesystem ops（無 commit）

## Background

cwd 已是 `~/Desktop/repo/public/Tandem`，git remote 已指向 Tandem.git，commit 2ac2b3a 已 push。
但這幾件事沒做：
1. **memory dir 內容 sed** — 8 個檔還含 `woody-harness` 字眼
2. **final verification**（test-bootstrap、fresh smoke、grep 殘留）
3. **archive inbox**（inbox 還停在原 Phase 0 prompt）
4. **舊 memory slug dir 殘檔** — `~/.claude-work/projects/-Users-woody-Desktop-repo-public-woody-harness/` 還在，裡面剩一個 Claude session `.jsonl`（不是 memory，可安全刪整個 dir）

## Step-by-step

### Step 1: Pre-flight

```bash
pwd | grep -q "/Tandem$" || { echo "FAIL: not in Tandem"; exit 1; }
git remote get-url origin | grep -q "Tandem.git" || { echo "FAIL: remote wrong"; exit 1; }
[ -d "$HOME/.claude-work/projects/-Users-woody-Desktop-repo-public-Tandem/memory" ] || { echo "FAIL: new memory dir missing"; exit 1; }
echo "PASS: pre-flight"
```

### Step 2: Sed memory dir 內容

```bash
NEW_MEM_DIR="$HOME/.claude-work/projects/-Users-woody-Desktop-repo-public-Tandem/memory"

grep -l "woody-harness" "$NEW_MEM_DIR"/*.md 2>/dev/null > /tmp/tandem-mem-list.txt
echo "--- files to sed ---"
cat /tmp/tandem-mem-list.txt
wc -l /tmp/tandem-mem-list.txt

[ -s /tmp/tandem-mem-list.txt ] && xargs sed -i '' 's/woody-harness/Tandem/g' < /tmp/tandem-mem-list.txt

# 驗證
if grep -q "woody-harness" "$NEW_MEM_DIR"/*.md 2>/dev/null; then
    echo "FAIL: memory still has woody-harness:"
    grep -n "woody-harness" "$NEW_MEM_DIR"/*.md
    exit 1
else
    echo "PASS: memory dir clean"
fi
```

注意：memory 檔名 `project_woody_harness.md` 的**檔名不改**（內容改即可）— 改檔名要連帶改 MEMORY.md 索引，超出本輪 scope。Phase A 敘事重構時再處理。

### Step 3: 清舊 memory slug dir

```bash
OLD_SLUG_DIR="$HOME/.claude-work/projects/-Users-woody-Desktop-repo-public-woody-harness"

# 安全檢查：確定裡面沒 memory/ 子目錄（已被 mv 走）
if [ -d "$OLD_SLUG_DIR/memory" ]; then
    echo "FAIL: old slug still has memory/ — abort"
    exit 1
fi

# 列內容讓 user 看
echo "--- 舊 slug dir 殘檔 ---"
ls -la "$OLD_SLUG_DIR"

# 刪
rm -rf "$OLD_SLUG_DIR"
[ ! -e "$OLD_SLUG_DIR" ] && echo "PASS: old slug dir removed"
```

### Step 4: Final verification

```bash
cd ~/Desktop/repo/public/Tandem

# 4a. memory.sh list 找得到
bash scripts/memory.sh list 2>&1 | head -10

# 4b. test-bootstrap 全綠
bash scripts/test-bootstrap.sh && echo "PASS: test-bootstrap" || { echo "FAIL: test-bootstrap"; exit 1; }

# 4c. bash -n bootstrap
bash -n bootstrap.sh && echo "PASS: bootstrap syntax"

# 4d. fresh bootstrap smoke
TMPCHK=$(mktemp -d)
cd "$TMPCHK"
bash ~/Desktop/repo/public/Tandem/bootstrap.sh tandem-smoke-test
[ -f tandem-smoke-test/CLAUDE.md ] && echo "PASS: fresh bootstrap CLAUDE.md"
[ -f tandem-smoke-test/.claude/commands/inbox.md ] && echo "PASS: slash commands copied"

# 清 throwaway
SLUG_TS=$(echo "$TMPCHK/tandem-smoke-test" | sed 's|/|-|g')
rm -rf "$TMPCHK" "$HOME/.claude-work/projects/$SLUG_TS"
cd ~/Desktop/repo/public/Tandem

# 4e. 全 repo grep 沒 woody-harness（除歷史外）
remaining=$(grep -rl "woody-harness" . \
  --include="*.md" --include="*.sh" --include="*.json" --include="*.conf" \
  --exclude-dir=".git" --exclude-dir="_archive" --exclude-dir="dogfood" --exclude-dir="retros" \
  | grep -vE "^./docs/prompts/[0-9]+-" \
  | grep -v "^./docs/prompts/phase-" \
  | grep -v "^./docs/prompts/_inbox.md" \
  | grep -v "^./CHANGELOG.md" || true)
[ -z "$remaining" ] && echo "PASS: zero woody-harness in non-history" || { echo "FAIL: $remaining"; exit 1; }
```

要全 PASS 才繼續 step 5。

### Step 5: Archive

```bash
bash scripts/archive-prompts.sh
git push origin main
```

archive 會把本檔歸檔成 `docs/prompts/<date>-tandem-phase-0-followup.md` 並清空 inbox。

## Hard rules

1. memory 檔名 `project_woody_harness.md` **不改檔名**（只改內容）— 檔名變動牽涉 MEMORY.md 索引，留 Phase A
2. 任何 step FAIL → STOP 印錯誤、不強跑
3. 通知：成功 → `afplay /System/Library/Sounds/Glass.aiff` + osascript notification；失敗 → `say -v Mei-Jia "卡住了"`
4. 不 auto-queue 下一輪

## Result block

跑完 append 到本檔結尾：

```markdown
## Result

**Status**: ✅ shipped | ❌ blocked
**Commits**: 1 (archive only)
<sha> chore: archive tandem-phase-0-followup inbox prompt + result

**Memory sed**:
- files sed'd: <N>
- post-sed grep clean: PASS / FAIL

**Old slug cleanup**:
- old slug dir removed: PASS / FAIL

**Verification**:
- memory.sh list works: PASS / FAIL
- test-bootstrap.sh: PASS / FAIL
- bash -n bootstrap: PASS / FAIL
- fresh bootstrap smoke: PASS / FAIL
- zero woody-harness in non-history: PASS / FAIL

**Push**: ✅ pushed / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ⚠️ blocked
**Commits**: 0 (no new commits — archive pending)

**Memory sed**:
- files sed'd: 8
- post-sed grep clean: PASS

**Old slug cleanup**:
- old slug dir removed: PASS

**Verification**:
- memory.sh list works: PASS
- test-bootstrap.sh: FAIL
- bash -n bootstrap: (skipped — blocked at test-bootstrap)
- fresh bootstrap smoke: (skipped)
- zero woody-harness in non-history: (skipped)

**Push**: ⏸ pending (blocked before archive commit)
**Blockers**: test-bootstrap.sh fails 3/32 — shared memory `~/.claude-work/_shared/memory/` exists from T-1a promote testing (placeholder only: `pre_shared.md`), missing seed files: `feedback_terse_zh.md`, `feedback_workflow_split.md`, `feedback_model_split.md`. Bootstrap seed-on-first-run skipped because dir existed. Fix: copy template seeds to `_shared/memory/` + update its `MEMORY.md` + run `memory.sh sync`.
