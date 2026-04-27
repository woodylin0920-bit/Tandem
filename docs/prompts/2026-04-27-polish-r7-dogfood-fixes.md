# Polish-r7: dogfood UX findings (bootstrap.sh upgrade/remove output polish)

## Goal

把 dogfood 報告（`docs/dogfood/2026-04-28-upgrade-remove.md`）找出的 6 個 UX 問題一次修光（dogfood 報告寫 7 個，但 #3「dirty-tree 文件 mismatch」實際已 align — UPGRADE.md line 31 寫「warn but continue」，不是 dogfood 寫的「clean tree required」，是 sonnet 之前讀錯。剩 6 個真改動）。

## Execution profile

- model: sonnet
- effort: small（單檔多處字串改動 + 一個 doc 同步）
- 2 commits（polish / archive）

## Background context

S-1 ship 後跑 4 scenarios dogfood 全 PASS、無 logic bug；6 個 cosmetic UX 問題待修。所有改動集中在 `bootstrap.sh`（4 段 function: `upgrade_dry_run`, `upgrade_apply`, `remove_dry_run`, `remove_apply`），加 `docs/UPGRADE.md` 一處字串調整為對齊 dogfood 觀察。

關鍵脈絡：
- bootstrap.sh line 85 = dirty-tree WARN（單行、無分隔）
- bootstrap.sh line 155 = `Would overwrite` 標題（dry-run + apply 兩種模式都用）
- bootstrap.sh line 234 = upgrade 完成 `Done. N files written. Run 'git -C $target diff'`
- bootstrap.sh line 347 = `Would delete` 標題（dry-run + apply 兩種模式都用）
- bootstrap.sh line 376 = `Would remove empty dirs`
- bootstrap.sh line 422 = remove 完成 `Done. N files deleted. Memory preserved at...`

---

## Commit 1: `feat(bootstrap): polish upgrade/remove output (active tense, git status hint, settings count, dirty-tree visibility)`

修 6 處（按 dogfood report 編號）。**所有「Would ...」標題改成 dual-mode** — dry-run 維持「Would」，`--apply` 切換到 active tense。

### Fix #1 — active-tense headers when --apply

**bootstrap.sh line 155** `echo "Would overwrite (${#will_overwrite[@]}):"`：
改為 dual-mode（用 `$apply` flag 變數，已存在）：
```bash
if $apply; then
    echo "Overwriting (${#will_overwrite[@]}):"
else
    echo "Would overwrite (${#will_overwrite[@]}):"
fi
```

**bootstrap.sh line 166** `echo "Would merge .claude/settings.json:"`：
```bash
if $apply; then
    echo "Merging .claude/settings.json:"
else
    echo "Would merge .claude/settings.json:"
fi
```

**bootstrap.sh line 347** `echo "Would delete (${#will_delete[@]} files):"`：
```bash
if $apply; then
    echo "Deleting (${#will_delete[@]} files):"
else
    echo "Would delete (${#will_delete[@]} files):"
fi
```

**bootstrap.sh line 376** `echo "Would remove empty dirs (if any):"`：
```bash
if $apply; then
    echo "Removing empty dirs (if any):"
else
    echo "Would remove empty dirs (if any):"
fi
```

> 如果你發現 remove 也有 `Would reverse-merge` / `Would NOT touch` 之類其他 "Would" 標題，**全部一起加 dual-mode**。`Skipped — user-modified` 跟 `Up-to-date` 屬於描述狀態不是動作，不用改。`Run with --apply` 那行只在 dry-run 印（已存在條件式），無需改。

### Fix #2 — git diff → git status hint after upgrade

**bootstrap.sh line 234** 現在：
```bash
echo "Done. $n_written files written. Run 'git -C $target diff' to inspect."
```

改成（同時融入 fix #4）：
```bash
# Build summary based on what actually happened
parts=()
[ "$n_written" -gt 0 ] && parts+=("$n_written file$([ "$n_written" -ne 1 ] && echo s) written")
[ "$settings_merged" = "true" ] && parts+=("settings.json merged")
summary=$(IFS=", "; echo "${parts[*]}")
[ -z "$summary" ] && summary="no changes"

echo ""
echo "Done. $summary."
echo "Run 'git -C $target status' to see all new/modified files,"
echo "then 'git -C $target diff' for content of modified files."
```

> `$settings_merged` 變數可能還沒存在 — 你需要在 `upgrade_apply` 函式裡，每次跑 settings.json merge 後 set `settings_merged=true`（預設 false）。如果現有 code 已經有 equivalent 變數（例如 `n_settings_changed`），就用既有的，不要重複定義。

### Fix #4 — settings count breakdown

已併入 Fix #2 的 summary 構造（`parts` 陣列分別 push「N files written」跟「settings.json merged」）。**這樣輸出會像**：
- 只覆蓋檔：`Done. 6 files written.`
- 只 merge settings：`Done. settings.json merged.`
- 兩者都有：`Done. 6 files written, settings.json merged.`
- 都沒：`Done. no changes.`（idempotent 重跑情境）

### Fix #5 — shorten skip-if-modified diff paths

定位現有 print（在 `upgrade_dry_run` 跟 `remove_dry_run` 兩處 `Skipped — user-modified` 段）：

現在大致是：
```bash
echo "    → diff: diff $target/$rel_path $harness/$src_path"
```

改成：
```bash
# Use ~ substitution for $HOME to shorten
short_target=$(echo "$target" | sed "s|$HOME|~|")
short_harness=$(echo "$harness" | sed "s|$HOME|~|")
echo "    → diff: diff $short_target/$rel_path $short_harness/$src_path"
```

> sed 用 `s|...|...|` 形式避免被路徑裡的 `/` 干擾。如果路徑不含 `$HOME`（例如 mktemp 在 `/tmp` 下）`sed` 會 noop，輸出原路徑 — OK。

### Fix #6 — add `git status` hint after `--remove --apply`

**bootstrap.sh line 422** 現在：
```bash
echo "Done. $n_deleted files deleted. Memory preserved at $mem_dir/."
```

改成：
```bash
echo ""
echo "Done. $n_deleted files deleted. Memory preserved at $mem_dir/."
echo "Run 'git -C $target status' to see deleted files before committing."
```

### Fix #7 — dirty-tree WARN visual separator

**bootstrap.sh line 85** 現在：
```bash
echo "[upgrade] WARN: target working tree is dirty (continuing anyway)"
```

改成：
```bash
echo ""
echo "⚠️  WARNING: target working tree is dirty"
echo "   Continuing — your existing changes will mix with upgrade changes."
echo "   Consider 'git stash' first, or commit existing changes, before re-running."
echo ""
```

> 4 行替換 1 行，前後加空行做視覺分隔。emoji `⚠️` 跟 dry-run 輸出其他段對齊（dry-run 已用 ✅/⚠️/❌ 等 emoji 在 Result block 慣例內）。

### Doc sync — UPGRADE.md（其實已經對齊，只做 micro polish）

打開 `docs/UPGRADE.md`，line 31 附近：
```
4. Working tree dirty → warn but continue (so you can review the upgrade as a single commit)
```

維持原意，但補一行說明 stash 建議（呼應新的 WARN 訊息）：
```
4. Working tree dirty → warn but continue (so you can review the upgrade as a single commit). If you'd rather not mix existing changes with upgrade output, run `git stash` first or commit before upgrading.
```

---

## Verification（commit 前自己跑）

```bash
HARNESS=$(pwd)
TMP=$(mktemp -d -t wh-r7-XXXXXX)
cd "$TMP"

# 1. bash syntax 沒壞
bash -n "$HARNESS/bootstrap.sh" && echo "PASS: bash -n" || { echo "FAIL: syntax"; exit 1; }

# 2. test-bootstrap.sh 全綠
bash "$HARNESS/scripts/test-bootstrap.sh" && echo "PASS: test-bootstrap 32/32" || { echo "FAIL"; exit 1; }

# 3. fresh bootstrap 沒壞
bash "$HARNESS/bootstrap.sh" test-r7 || { echo "FAIL: bootstrap broke"; exit 1; }
echo "PASS: bootstrap test-r7 created"

# 4. degrade test-r7（砍 sync.md），跑 dry-run，預期看到 "Would overwrite (1)"（不是 "Overwriting"）
rm -f "$TMP/test-r7/.claude/commands/sync.md"
out_dry=$(bash "$HARNESS/bootstrap.sh" --upgrade-existing "$TMP/test-r7" 2>&1)
echo "$out_dry" | grep -q "Would overwrite" && echo "PASS: dry-run uses 'Would overwrite'" || { echo "FAIL: $out_dry"; exit 1; }
echo "$out_dry" | grep -q "Run with --apply" && echo "PASS: dry-run hint" || { echo "FAIL"; exit 1; }

# 5. apply 跑出來預期看到 "Overwriting (1):" + 新 summary
out_apply=$(bash "$HARNESS/bootstrap.sh" --upgrade-existing "$TMP/test-r7" --apply 2>&1)
echo "$out_apply" | grep -q "Overwriting" && echo "PASS: apply uses 'Overwriting'" || { echo "FAIL: '$out_apply'"; exit 1; }
echo "$out_apply" | grep -q "git -C.*status" && echo "PASS: git status hint present" || { echo "FAIL"; exit 1; }

# 6. dirty-tree WARN 有新格式
cd "$TMP/test-r7"
echo "garbage" > dirty-file
git add dirty-file
out_dirty=$(bash "$HARNESS/bootstrap.sh" --upgrade-existing "$TMP/test-r7" 2>&1)
echo "$out_dirty" | grep -q "⚠️  WARNING: target working tree is dirty" && echo "PASS: WARN new format" || { echo "FAIL"; exit 1; }
git reset --hard HEAD 2>/dev/null
rm -f dirty-file 2>/dev/null

# 7. remove --apply 有 git status hint
out_rm=$(bash "$HARNESS/bootstrap.sh" --remove "$TMP/test-r7" --apply 2>&1)
echo "$out_rm" | grep -q "git -C.*status" && echo "PASS: remove git status hint" || { echo "FAIL: '$out_rm'"; exit 1; }

# 8. UPGRADE.md 提到 git stash
grep -q "git stash" "$HARNESS/docs/UPGRADE.md" && echo "PASS: UPGRADE.md mentions stash" || { echo "FAIL"; exit 1; }

# 清理
cd "$HARNESS"
SLUG=$(echo "$TMP/test-r7" | sed 's|/|-|g')
rm -rf "$TMP" "$HOME/.claude-work/projects/$SLUG"
```

要全 PASS 才 commit 1。

---

## Commit 2 (auto): archive

跑 `bash scripts/archive-prompts.sh` 把 `docs/prompts/_inbox.md` 內容歸檔成 `docs/prompts/<date>-polish-r7-dogfood-fixes.md` 並補 Result block + 清空 _inbox.md。

---

## Hard rules

1. **DO NOT** modify files outside這些：`bootstrap.sh`（commit 1）、`docs/UPGRADE.md`（commit 1）。
2. **DO NOT** auto-queue 下一輪。跑完 archive 後 STOP。
3. 任何 verification step FAIL → STOP + 印錯誤 + 不 commit broken state。
4. 不要破壞 dry-run 行為 —「Would」字眼必須繼續存在 in dry-run path（只在 `$apply` true 時才換 active tense）。
5. 不要動 `bash bootstrap.sh <new-name>` 的 new-project flow。
6. macOS BSD sed 用 `sed -i ''`（per env_paths memory）；本輪用的 `sed "s|...|~|"` 是純 stream substitution 不是 in-place，所以兩種 sed 都行，注意別搞混。
7. 用 git mv / git add 妥善處理。
8. 通知：成功 → `afplay /System/Library/Sounds/Glass.aiff` + `osascript -e 'display notification "polish-r7 done" with title "woody-harness"'`；失敗 → `say -v Mei-Jia "卡住了"`（per macOS notification memory）。

## Result block convention

跑完最後 append 到本檔案結尾：

```markdown
## Result

**Status**: ✅ shipped | ❌ blocked
**Commits**: 2 (incl. archive)
<sha> feat(bootstrap): polish upgrade/remove output (active tense, git status hint, settings count, dirty-tree visibility)
<sha> chore: archive polish-r7-dogfood-fixes inbox prompt + result

**Verification**:
- bash -n bootstrap.sh: PASS / FAIL
- test-bootstrap 32/32: PASS / FAIL
- fresh bootstrap works: PASS / FAIL
- dry-run still uses "Would overwrite": PASS / FAIL
- --apply uses "Overwriting": PASS / FAIL
- post-upgrade git status hint: PASS / FAIL
- dirty-tree WARN new format (⚠️ WARNING + indented detail): PASS / FAIL
- post-remove git status hint: PASS / FAIL
- UPGRADE.md mentions git stash: PASS / FAIL

**Push**: ✅ pushed to origin/main / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ✅ shipped
**Commits**: 2 (incl. archive)
b9e1134 feat(bootstrap): polish upgrade/remove output (active tense, git status hint, settings count, dirty-tree visibility)
<archive-sha> chore: archive polish-r7-dogfood-fixes inbox prompt + result

**Verification**:
- bash -n bootstrap.sh: PASS
- test-bootstrap 32/32: PASS
- fresh bootstrap works: PASS
- dry-run still uses "Would overwrite": PASS
- --apply uses "Overwriting": PASS
- post-upgrade git status hint: PASS
- dirty-tree WARN new format (⚠️ WARNING + indented detail): PASS
- post-remove git status hint: PASS
- UPGRADE.md mentions git stash: PASS

**Push**: ✅ pushed to origin/main
**Blockers**: none
