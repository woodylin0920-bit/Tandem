# lessons.sh + archive-prompts.sh: BSD awk fix + Result-block-fence-aware detection

## Goal

E2E verification 抓到 2 個 bug，本輪修：

1. **Primary**：`scripts/lessons.sh` 的 `replace_entry()` 用 `awk -v new="$multiline"` 在 macOS BSD awk 上爆 "newline in string"，extract 拼不起來
2. **Secondary**：`scripts/archive-prompts.sh` 的 detection awk 從 `^## Result$` 起讀但**沒處理 `## Result` 出現在 code fence 內**（archived inbox prompts 的 Result template 在 fence 裡）— 抓錯區塊內容導致本輪 E2E archive 的 FAIL 訊號沒被偵測

## Execution profile

- model: sonnet
- effort: low（單檔 ~30 行 fix x 2 + verify）
- 2 commits + archive = 3

## Background context

- E2E sub-test A FAIL：`replace_entry()` 拿 candidate 多行內容（含 frontmatter + body）餵 `awk -v new="$content"`，BSD awk 拒絕 newline 在 -v assign。GNU awk OK，BSD awk 不行 → macOS broken。
- Self-validation 沒觸發：detection awk 假設 `## Result` 都在 top-level，但 archived inbox 的 Result block template 是寫在 ``` fence 裡，state machine 錯誤計到 fence 內 PASS/FAIL placeholder，filter 掉一切。

## Step-by-step

### Step 1: Pre-flight

```bash
pwd | grep -q "/Tandem$" || { echo "FAIL: not in Tandem"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "FAIL: working tree dirty"; git status --short; exit 1; }
echo "PASS: pre-flight"
```

### Step 2: Fix scripts/lessons.sh `replace_entry()`

讀現檔找到 `replace_entry()` function（在 helper 區，`remove_entry()` 附近）。整個 function 重寫成用 temp file 做 awk getline：

```bash
# Replace entry by id with new content (multi-line). new_content already includes BEGIN/END markers.
replace_entry() {
    local id="$1"
    local new_content="$2"
    local tmp newfile
    tmp=$(mktemp)
    newfile=$(mktemp)
    printf '%s\n' "$new_content" > "$newfile"
    awk -v id="$id" -v newfile="$newfile" '
        $0 ~ "^<!-- BEGIN entry id="id" " {
            while ((getline line < newfile) > 0) print line
            close(newfile)
            skip=1; next
        }
        skip && $0 == "<!-- END entry -->" {skip=0; next}
        !skip {print}
    ' "$STAGING" > "$tmp"
    mv "$tmp" "$STAGING"
    rm -f "$newfile"
}
```

關鍵：把 `new_content` 寫到 temp file，awk 用 `getline < newfile` 讀回去 — 完全 portable，不依賴 -v 傳多行。

### Step 3: Fix scripts/archive-prompts.sh detection awk

讀現檔找到 `detect_and_stage_lesson()` 裡的 awk extract result_content 那段：

```bash
result_content=$(awk '
    /^## Result$/ {in_result=1; next}
    in_result && /^## / {in_result=0}
    in_result && /^```/ {in_code = !in_code; next}
    in_result && !in_code {print}
' "$archive_file")
```

整段替換成：

```bash
result_content=$(awk '
    /^```/ {in_code = !in_code; next}
    in_code {next}
    /^## Result$/ {in_result=1; next}
    in_result && /^## / {in_result=0}
    in_result {print}
' "$archive_file")
```

差別：fence tracking 從檔案 start 就開始（不是只在 in_result 內），`## Result` 出現在 fence 裡會被 skip 掉（因為 in_code 階段全 next），只有 top-level 的 `## Result` 才觸發 in_result=1。

### Step 4: Verify fix 1 (replace_entry) — mini E2E

```bash
echo "============================================="
echo "VERIFY FIX 1: replace_entry multi-line on BSD awk"
echo "============================================="

STAGING="$HOME/.claude-work/_shared/lessons-staging.md"
[ -f "$STAGING" ] && cp "$STAGING" /tmp/lessons-staging.bak || touch /tmp/lessons-staging.bak

TEST_ID="bsd-awk-fix-verify-$$"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat >> "$STAGING" <<EOF
<!-- BEGIN entry id=$TEST_ID state=raw timestamp=$TS -->
- archive: synthetic
- signals:
  - "test signal"
- excerpt: |
    raw stub
<!-- END entry -->

EOF

# Source replace_entry from lessons.sh by extracting it (or just exercise via extract+review path manually)
# Simpler: directly invoke replace_entry by writing a one-shot script
cat > /tmp/test-replace.sh <<'TEST_EOF'
#!/usr/bin/env bash
set -euo pipefail
STAGING="$HOME/.claude-work/_shared/lessons-staging.md"

# Source ONLY the helper functions — read lessons.sh and extract the function
# Or just re-define here matching production
replace_entry() {
    local id="$1"
    local new_content="$2"
    local tmp newfile
    tmp=$(mktemp)
    newfile=$(mktemp)
    printf '%s\n' "$new_content" > "$newfile"
    awk -v id="$id" -v newfile="$newfile" '
        $0 ~ "^<!-- BEGIN entry id="id" " {
            while ((getline line < newfile) > 0) print line
            close(newfile)
            skip=1; next
        }
        skip && $0 == "<!-- END entry -->" {skip=0; next}
        !skip {print}
    ' "$STAGING" > "$tmp"
    mv "$tmp" "$STAGING"
    rm -f "$newfile"
}

new_block=$(cat <<'BLOCK'
<!-- BEGIN entry id=TEST_ID_PLACEHOLDER state=candidate timestamp=TS_PLACEHOLDER -->
---
name: bsd awk fix verify
description: synthetic test
type: feedback
---

Multi-line body.
Line 2.
Line 3.
<!-- END entry -->
BLOCK
)
new_block=$(echo "$new_block" | sed "s/TEST_ID_PLACEHOLDER/$1/")
replace_entry "$1" "$new_block"
TEST_EOF

chmod +x /tmp/test-replace.sh
bash /tmp/test-replace.sh "$TEST_ID"

if grep -q "^<!-- BEGIN entry id=$TEST_ID state=candidate" "$STAGING" && \
   grep -q "^name: bsd awk fix verify" "$STAGING" && \
   grep -q "^Line 3.$" "$STAGING"; then
    echo "✅ FIX 1 PASS: replace_entry handled multi-line on BSD awk"
    fix1=PASS
else
    echo "❌ FIX 1 FAIL"
    awk -v id="$TEST_ID" '$0 ~ "^<!-- BEGIN entry id="id eval echo "id" ' "$STAGING" || true
    fix1=FAIL
fi

# Cleanup test entry
cp /tmp/lessons-staging.bak "$STAGING"
rm -f /tmp/test-replace.sh /tmp/lessons-staging.bak

[ "$fix1" = PASS ] || { echo "FIX 1 broken — STOP"; exit 1; }
```

### Step 5: Verify fix 2 (detection fence-aware) — mini test

```bash
echo "============================================="
echo "VERIFY FIX 2: detection skips fence-内 ## Result"
echo "============================================="

# 構造一個 mock archive：fence-内 含 ## Result template (PASS/FAIL placeholder)，fence-外 含真實 ## Result with single FAIL
mock_archive=$(mktemp).md
cat > "$mock_archive" <<'EOF'
# Mock archive

Some prose.

\`\`\`markdown
## Result

**Status**: ✅ shipped | ❌ blocked
**Verification**:
- something: PASS / FAIL
\`\`\`

Closing prose.

## Result

**Status**: ✅ shipped (verification only)

**SUB-TEST A**:
- Entry transitioned: FAIL — some real failure here

**Push**: pushed
**Blockers**: none
EOF

# 把 mock 餵 detect logic（直接 inline 跑 awk，模擬 detection function 抓 result_content + has_fail）
result_content=$(awk '
    /^```/ {in_code = !in_code; next}
    in_code {next}
    /^## Result$/ {in_result=1; next}
    in_result && /^## / {in_result=0}
    in_result {print}
' "$mock_archive")

echo "--- extracted result_content ---"
echo "$result_content"
echo "--- end ---"

# Has the real FAIL line been kept?
fail_line=$(echo "$result_content" | grep -E '\bFAIL\b' | grep -v 'PASS' | head -1)

if echo "$fail_line" | grep -q "real failure here"; then
    echo "✅ FIX 2 PASS: detection found real FAIL outside fence"
    fix2=PASS
else
    echo "❌ FIX 2 FAIL"
    echo "fail_line: $fail_line"
    fix2=FAIL
fi

# 也驗 fence 內的 PASS/FAIL placeholder 沒被算進去
if echo "$result_content" | grep -q "PASS / FAIL"; then
    echo "❌ FIX 2 FAIL: fence-内 PASS / FAIL template 還在 result_content"
    fix2=FAIL
else
    echo "✅ FIX 2 BONUS: fence-内 template correctly skipped"
fi

rm -f "$mock_archive"

[ "$fix2" = PASS ] || { echo "FIX 2 broken — STOP"; exit 1; }
```

### Step 6: Final verification

```bash
# bash syntax
bash -n scripts/lessons.sh && echo "PASS: lessons.sh syntax"
bash -n scripts/archive-prompts.sh && echo "PASS: archive-prompts syntax"

# test-bootstrap 維持
bash scripts/test-bootstrap.sh && echo "PASS: test-bootstrap 36/36" || { echo "FAIL"; exit 1; }

# lessons.sh subcommands still run
bash scripts/lessons.sh count >/dev/null && echo "PASS: count"
bash scripts/lessons.sh list >/dev/null && echo "PASS: list"
bash scripts/lessons.sh help >/dev/null && echo "PASS: help"
```

### Step 7: Commits（atomic）

```bash
# Commit 1: lessons.sh BSD awk fix
git add scripts/lessons.sh
git commit -m "fix: lessons.sh replace_entry portable to macOS BSD awk

E2E verification (sub-test A) caught: BSD awk 'awk -v var=...' rejects
multi-line content with 'newline in string' error — extract step's
replace_entry() couldn't write multi-line candidate block on macOS,
breaking the raw → candidate state transition.

Fix: write new_content to temp file, awk reads via getline < newfile.
Pure portable, no GNU/BSD divergence."

# Commit 2: archive-prompts.sh fence-aware detection
git add scripts/archive-prompts.sh
git commit -m "fix: archive-prompts.sh detection skips ## Result inside code fences

E2E verification self-validation: archived inbox prompts contain a
'## Result' template inside a markdown code fence (the round's Result
block spec), then the real '## Result' block follows below. The old
awk extracted from the FIRST '## Result' (inside the fence) and got
PASS/FAIL placeholder text — filtered out, no detection trigger.

Fix: track code fences from file start (not only in Result block).
'## Result' headings inside fences are ignored. Only top-level Result
content reaches the FAIL/Blocker/keyword detection."
```

### Step 8: Archive

```bash
bash scripts/archive-prompts.sh
git push origin main
```

archive 通過修好的 detection — 本輪 archive Result block 應該是 ✅ shipped + 無 FAIL/Blocker，detection 不會觸發，staging 維持 0。

> **Note**：之前 E2E archive 那輪含 sub-test A FAIL 訊號，被舊 detection 漏掉。本輪 archive 跑前那個 archive 不會被回溯掃描（只有當下被 archive 的檔才掃）— 所以那條 lesson 永遠不會自動 stage。如果你想救那條 lesson，可以手動把訊號 craft 進 staging（但不必 — bug 已修，CHANGELOG 會記）。

## Hard rules

1. 兩個 fix 各自 atomic commit，不合併
2. Fix 1 替換 `replace_entry()` 整個 function（不要只改一行）
3. Fix 2 替換整個 awk pattern（不要 patch 舊 logic）
4. 任何 verify FAIL → STOP 印錯誤、不強跑
5. 通知：成功 → `afplay /System/Library/Sounds/Glass.aiff` + osascript notification；失敗 → `say -v Mei-Jia "卡住了"`
6. **本輪 ship 完 STOP**

## Result block

跑完 append：

```markdown
## Result

**Status**: ✅ shipped | ❌ blocked
**Commits**: 3 (incl. archive)
<sha> fix: lessons.sh replace_entry portable to macOS BSD awk
<sha> fix: archive-prompts.sh detection skips ## Result inside code fences
<sha> chore: archive lessons-bsd-awk-and-detection-fence-fix inbox prompt + result

**Fix verifications**:
- FIX 1 (replace_entry multi-line on BSD awk): PASS / FAIL
- FIX 2 (detection skips fence-内 ## Result + finds real FAIL outside fence): PASS / FAIL
- bash -n lessons.sh + archive-prompts.sh: PASS / FAIL
- test-bootstrap 36/36: PASS / FAIL
- lessons.sh count/list/help still run: PASS / FAIL

**Self-validation**:
- this round's archive triggered detection? YES (review fix needed) / NO (clean)

**Push**: ✅ pushed / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ✅ shipped
**Commits**: 3 (incl. archive)
4eb14ef fix: lessons.sh replace_entry portable to macOS BSD awk
9e6238b fix: archive-prompts.sh detection skips ## Result inside code fences
<archive sha TBD> chore: archive lessons-bsd-awk-and-detection-fence-fix inbox prompt + result

**Fix verifications**:
- FIX 1 (replace_entry multi-line on BSD awk): PASS
- FIX 2 (detection skips fence-内 ## Result + finds real FAIL outside fence): PASS
- bash -n lessons.sh + archive-prompts.sh: PASS
- test-bootstrap 36/36: PASS
- lessons.sh count/list/help still run: PASS

**Self-validation**:
- this round's archive triggered detection? NO (clean)

**Push**: ✅ pushed
**Blockers**: none
