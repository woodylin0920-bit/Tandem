# Phase C E2E verification: lessons.sh extract + review real run

## Goal

Phase C lessons loop 截至目前只 detection + count/list 跑過。**extract（headless `claude -p`）+ review（互動 promote/delete）** 從沒實測 — 如果 claude CLI 介面變了、prompt 格式錯了、或 review 流邏輯有 bug，整條 self-improving loop 死掉。本輪做 end-to-end 驗證，**不留任何 test 殘檔**。

## Execution profile

- model: sonnet
- effort: medium（多 step verify + cleanup 要乾淨）
- 0 deliverable commits（純 verification round）+ archive = 1 commit
- **本輪不應該對 Tandem repo 有任何 code 改動** — 全部 test 動作在 user-level state（shared memory + staging）+ 跑完還原

## Background context

- `lessons.sh extract` 用 `claude -p "..."` headless 餵 raw signals → AI 寫 candidate（含 frontmatter + Why/How body）
- `lessons.sh review` 互動 walk candidates，default action `[p]romote-shared` 把 candidate 寫進 `~/.claude-work/_shared/memory/<slug>.md` 並 append 索引到 `~/.claude-work/_shared/memory/MEMORY.md`
- 測試需考慮：claude CLI 可能需要 auth / API key 在 env / 不同回應格式

## Two-sub-test 策略

| Sub-test | 目標 | 失敗 means |
|---|---|---|
| **A. extract test** | 驗 `claude -p` 真能跑 + 輸出可被 lessons.sh parse 成 candidate state | claude CLI 介面破 / prompt 格式不被 model 理解 / parsing 邏輯錯 |
| **B. review test (manual candidate)** | 跳過 extract 直接 inject 已知 candidate，驗 review 互動 + promote 真寫入 shared memory | review 邏輯錯 / slug 提取錯 / shared MEMORY.md append 錯 |

A 失敗不擋 B（兩條獨立路徑）。本輪結束 Result block 分開報告兩個 sub-test 結果。

## Step-by-step

### Step 1: Pre-flight + snapshot

```bash
pwd | grep -q "/Tandem$" || { echo "FAIL: not in Tandem"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "FAIL: working tree dirty"; git status --short; exit 1; }

STAGING="$HOME/.claude-work/_shared/lessons-staging.md"
SHARED_MEM="$HOME/.claude-work/_shared/memory"
TEST_DIR="/tmp/tandem-lessons-e2e-$$"
mkdir -p "$TEST_DIR"

# Snapshot pre-test state
[ -f "$STAGING" ] && cp "$STAGING" "$TEST_DIR/staging.snapshot" || touch "$TEST_DIR/staging.snapshot"
cp "$SHARED_MEM/MEMORY.md" "$TEST_DIR/MEMORY.md.snapshot"
ls "$SHARED_MEM" > "$TEST_DIR/shared-files-before.txt"

echo "PASS: pre-flight + snapshots saved to $TEST_DIR"

# Verify staging starts empty (per v0.5.0 detection fix; no false positives)
n_pre=$(grep -c '^<!-- BEGIN entry' "$STAGING" 2>/dev/null || echo 0)
[ "$n_pre" = "0" ] && echo "PASS: staging starts empty" || { echo "WARN: staging has $n_pre pre-existing entries — test will leave them alone"; }
```

### Step 2: SUB-TEST A — extract (raw → candidate)

```bash
echo ""
echo "============================================="
echo "SUB-TEST A: extract (raw → candidate via claude -p)"
echo "============================================="

# Inject a synthetic raw entry into staging (simulates what archive-prompts.sh would write)
TEST_ID="e2e-extract-test-$$"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat >> "$STAGING" <<EOF
<!-- BEGIN entry id=$TEST_ID state=raw timestamp=$TS -->
- archive: docs/prompts/_archive/2026-04/synthetic-test.md
- status: ❌ blocked
- signals:
  - "**Status**: ❌ blocked"
  - "**Blockers**: pre-flight tree-clean check did not abort hard, only warned, and step 4 then trampled an in-progress feature branch"
  - "FAIL: working tree dirty assertion in step 1"
- excerpt: |
    ## Result
    Status: ❌ blocked
    Blockers: pre-flight tree-clean check did not abort hard, only warned,
    and step 4 then trampled an in-progress feature branch
<!-- END entry -->

EOF

echo "Injected raw entry: $TEST_ID"
bash scripts/lessons.sh count

# Check claude CLI is in PATH
if ! command -v claude >/dev/null 2>&1; then
    echo "WARN: claude CLI not in PATH — extract sub-test will exercise fallback path"
    A_RESULT="claude_not_in_path (fallback exercised)"
else
    echo "claude CLI present at: $(command -v claude)"

    # Run extract
    extract_output=$(bash scripts/lessons.sh extract 2>&1) || true
    echo "$extract_output"

    # Verify the entry transitioned raw → candidate
    if grep -q "^<!-- BEGIN entry id=$TEST_ID state=candidate" "$STAGING"; then
        A_RESULT="PASS"
        echo "✅ SUB-TEST A: PASS — entry transitioned to candidate"
        echo "--- candidate body excerpt ---"
        awk -v id="$TEST_ID" '$0 ~ "^<!-- BEGIN entry id="id" state=candidate" {grab=1} grab {print} $0 == "<!-- END entry -->" && grab {exit}' "$STAGING" | head -30
    else
        A_RESULT="FAIL — entry still raw or extract errored"
        echo "❌ SUB-TEST A: FAIL"
        echo "  Possible causes: claude CLI auth issue, model prompt format mismatch, parsing bug"
        echo "  Current entry state:"
        grep "^<!-- BEGIN entry id=$TEST_ID" "$STAGING" || echo "  (entry missing entirely)"
    fi
fi

echo "SUB-TEST A result: $A_RESULT"
```

### Step 3: Cleanup before SUB-TEST B

```bash
echo ""
echo "Cleanup: remove SUB-TEST A entry from staging before SUB-TEST B"

# Remove the test entry (whatever state it ended in)
tmp=$(mktemp)
awk -v id="$TEST_ID" '
    $0 ~ "^<!-- BEGIN entry id="id" " {skip=1; next}
    skip && $0 == "<!-- END entry -->" {skip=0; next}
    !skip {print}
' "$STAGING" > "$tmp"
mv "$tmp" "$STAGING"

# Verify removed
grep -q "^<!-- BEGIN entry id=$TEST_ID" "$STAGING" && { echo "FAIL: cleanup left $TEST_ID"; exit 1; } || echo "PASS: $TEST_ID removed from staging"
```

### Step 4: SUB-TEST B — review (candidate → promoted)

```bash
echo ""
echo "============================================="
echo "SUB-TEST B: review (candidate → promote-shared)"
echo "============================================="

# Inject a deterministic candidate entry (skip extract — test review independently)
TEST_ID_B="e2e-review-test-$$"
TS_B=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TEST_NAME="e2e review test lesson"
TEST_DESC="Synthetic lesson for verifying review promote path; cleaned up post-test."

cat >> "$STAGING" <<EOF
<!-- BEGIN entry id=$TEST_ID_B state=candidate timestamp=$TS_B -->
---
name: $TEST_NAME
description: $TEST_DESC
type: feedback
source-archive: docs/prompts/_archive/synthetic-test.md
---

E2E synthetic lesson body — verifying review-promote writes to shared memory.

**Why:** verifies the lessons.sh review code path actually writes a feedback memory file plus appends an index row to shared MEMORY.md, with deterministic slug derivation from the name field.

**How to apply:** test artifact only — should never appear in production memory.
<!-- END entry -->

EOF

echo "Injected candidate entry: $TEST_ID_B"

# Compute expected slug per lessons.sh logic:
#   name → lowercase → non-alphanumeric replaced with _
EXPECTED_SLUG="e2e_review_test_lesson"
EXPECTED_FILE="$SHARED_MEM/${EXPECTED_SLUG}.md"

# Sanity: file shouldn't exist yet
[ ! -f "$EXPECTED_FILE" ] || { echo "FAIL: expected file $EXPECTED_FILE already exists pre-test"; exit 1; }

# Snapshot MEMORY.md size before
size_before=$(wc -l < "$SHARED_MEM/MEMORY.md")

# Run review with piped answer "p" (promote-shared, default)
# review_logic loops while [ -n "$ids" ] picking each candidate
echo "Running: lessons.sh review with stdin = 'p\\n'"
review_output=$(printf 'p\n' | bash scripts/lessons.sh review 2>&1) || true
echo "$review_output"

# Verify expected file created
if [ -f "$EXPECTED_FILE" ]; then
    echo "✅ shared memory file created: $EXPECTED_FILE"
    file_check=PASS
else
    echo "❌ shared memory file MISSING: $EXPECTED_FILE"
    ls "$SHARED_MEM" | diff - "$TEST_DIR/shared-files-before.txt" || true
    file_check=FAIL
fi

# Verify MEMORY.md got new row
size_after=$(wc -l < "$SHARED_MEM/MEMORY.md")
if [ "$size_after" -gt "$size_before" ] && grep -q "$TEST_NAME" "$SHARED_MEM/MEMORY.md"; then
    echo "✅ shared MEMORY.md index appended"
    index_check=PASS
else
    echo "❌ shared MEMORY.md index NOT updated (size before=$size_before after=$size_after)"
    index_check=FAIL
fi

# Verify entry removed from staging
if grep -q "^<!-- BEGIN entry id=$TEST_ID_B" "$STAGING"; then
    echo "❌ staging still has $TEST_ID_B after promote"
    staging_check=FAIL
else
    echo "✅ staging cleaned of promoted entry"
    staging_check=PASS
fi

if [ "$file_check" = PASS ] && [ "$index_check" = PASS ] && [ "$staging_check" = PASS ]; then
    B_RESULT="PASS"
    echo "✅ SUB-TEST B: PASS"
else
    B_RESULT="FAIL (file=$file_check index=$index_check staging=$staging_check)"
    echo "❌ SUB-TEST B: FAIL"
fi
```

### Step 5: Cleanup — restore shared memory + staging to pre-test

**重要**：本輪是 verification round，**不准對 user state 留任何 test 殘檔**。

```bash
echo ""
echo "============================================="
echo "Cleanup: restore shared memory + staging"
echo "============================================="

# Remove test memory file if exists
if [ -f "$EXPECTED_FILE" ]; then
    rm "$EXPECTED_FILE"
    echo "Removed: $EXPECTED_FILE"
fi

# Restore MEMORY.md from snapshot
cp "$TEST_DIR/MEMORY.md.snapshot" "$SHARED_MEM/MEMORY.md"
echo "Restored: $SHARED_MEM/MEMORY.md"

# Restore staging from snapshot (also handles SUB-TEST A leftover)
cp "$TEST_DIR/staging.snapshot" "$STAGING"
echo "Restored: $STAGING"

# Verify cleanup
echo "Post-cleanup state:"
echo "  staging entries: $(grep -c '^<!-- BEGIN entry' "$STAGING" 2>/dev/null || echo 0)"
echo "  shared memory files diff vs before:"
ls "$SHARED_MEM" | diff - "$TEST_DIR/shared-files-before.txt" && echo "  (no diff — clean)"
echo "  MEMORY.md diff vs snapshot:"
diff "$TEST_DIR/MEMORY.md.snapshot" "$SHARED_MEM/MEMORY.md" >/dev/null && echo "  (no diff — clean)" || { echo "FAIL: MEMORY.md diverged from snapshot"; exit 1; }

# Cleanup test workspace
rm -rf "$TEST_DIR"
echo "Removed: $TEST_DIR"
```

### Step 6: Final verification — repo + user state untouched

```bash
echo ""
echo "Final state check:"

# Tandem repo working tree should be untouched (verification only, no commits)
git status --porcelain
[ -z "$(git status --porcelain)" ] || { echo "WARN: repo working tree has changes — should be clean for verification round"; git diff; }

# test-bootstrap still PASS
bash scripts/test-bootstrap.sh 2>&1 | tail -3

# staging unchanged from snapshot
n_final=$(grep -c '^<!-- BEGIN entry' "$STAGING" 2>/dev/null || echo 0)
echo "staging entries: $n_final (should match pre-test count)"

echo ""
echo "============================================="
echo "FINAL"
echo "============================================="
echo "SUB-TEST A (extract):  $A_RESULT"
echo "SUB-TEST B (review):   $B_RESULT"
```

### Step 7: Archive

```bash
bash scripts/archive-prompts.sh
git push origin main
```

archive 會把本檔歸檔成 `docs/prompts/<date>-phase-c-e2e-verification.md`。

> Note：本輪 archive 會通過 detection — 如果 Result block 含 ❌/Blocker/FAIL/keyword 觸發 staging。fixed regex 應該只在「實 status ❌」時觸發。本輪 ship 預期 ✅，detection 不該觸發；觸發即代表 Result block 寫法或 fixed regex 仍有問題。

## Hard rules

1. **本輪不對 Tandem repo 加 commit**（除了 archive prompt 自身那 commit），是純 verification round
2. SUB-TEST A 失敗（claude CLI 不可用 / 介面變）**不擋** SUB-TEST B；分別記錄結果
3. Cleanup 段必跑 — Result block 結尾要驗 user state restored 才 PASS
4. 通知：成功 → `afplay /System/Library/Sounds/Glass.aiff` + osascript notification；失敗 → `say -v Mei-Jia "卡住了"`
5. **本輪 ship 完 STOP** — 跑完回報，planner 接著手動跑 codex-audit

## Result block

跑完 append：

```markdown
## Result

**Status**: ✅ shipped (verification only) | ❌ blocked
**Commits**: 1 (archive only)
<sha> chore: archive phase-c-e2e-verification inbox prompt + result

**SUB-TEST A — extract (raw → candidate)**:
- claude CLI in PATH: YES / NO
- Entry transitioned raw → candidate: PASS / FAIL / N/A (claude unavailable)
- candidate body shape (frontmatter + Why/How): PASS / FAIL / N/A
- A overall: <result string from script>

**SUB-TEST B — review (candidate → promoted)**:
- shared memory file created: PASS / FAIL
- shared MEMORY.md index appended: PASS / FAIL
- staging cleaned of promoted entry: PASS / FAIL
- B overall: PASS / FAIL

**Cleanup**:
- shared memory file removed: PASS / FAIL
- shared MEMORY.md restored from snapshot: PASS / FAIL
- staging restored from snapshot: PASS / FAIL
- /tmp test workspace removed: PASS / FAIL
- Tandem repo working tree clean: PASS / FAIL

**Self-validation (regex fix)**:
- this round's archive triggered detection? YES (review fix needed) / NO

**Findings (if any)**:
- <fill if A or B FAIL — what was the actual error / unexpected behavior>

**Push**: ✅ pushed
**Blockers**: none

## Result

**Status**: ✅ shipped (verification only)
**Commits**: 1 (archive only)

**SUB-TEST A — extract (raw → candidate)**:
- claude CLI in PATH: YES
- Entry transitioned raw → candidate: FAIL
- candidate body shape (frontmatter + Why/How): N/A
- A overall: FAIL — BSD awk `-v new=...` with embedded newlines raises "newline in string" error; `replace_entry()` in lessons.sh cannot replace multi-line content on macOS BSD awk

**SUB-TEST B — review (candidate → promoted)**:
- shared memory file created: PASS
- shared MEMORY.md index appended: PASS
- staging cleaned of promoted entry: PASS
- B overall: PASS

**Cleanup**:
- shared memory file removed: PASS
- shared MEMORY.md restored from snapshot: PASS
- staging restored from snapshot: PASS
- /tmp test workspace removed: PASS
- Tandem repo working tree clean: PASS

**Self-validation (regex fix)**:
- this round's archive triggered detection? NO

**Findings (if any)**:
- Sub-test A root cause: `replace_entry()` uses `awk -v new="$new_content"` where `$new_content` is the multi-line candidate block. BSD awk (macOS default) does not allow literal newlines in `-v` variable assignments — raises `awk: newline in string`. The entry stays `state=raw`. Fix: escape newlines before passing to awk, or use a tmp-file approach instead of `-v`.
- Sub-test B passed cleanly: review → promote writes shared memory file, appends MEMORY.md index row, clears staging entry. No issues.
```
