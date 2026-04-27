# Inbox: self-dogfood 殘留清理 + detection regex 加強（A+B 合一）

## Execution profile
- model: sonnet
- effort: medium
- why: 兩件相關小修，A 清乾淨 staging + archive 殘留，B 強化 detection 防再撞 false positive；風險低、相依清楚

---

## Phase 1（A）— 清 staging false positive + 補搬 bug-fix archive

### 1A. 清 lessons staging 那條 meta-text false positive
背景：v0.5.0-release archive 的 Result block 散文（「no FAIL lines」這類反身描述）被 detection 抓進 staging，是誤判。

步驟：
1. `bash scripts/lessons.sh review` 進互動模式
2. 找出 meta-text false positive（反身散文，不是真 lesson）
3. 用 review 選項丟掉（reject / discard，**不要** promote 到 shared）
4. `bash scripts/lessons.sh status` 確認 staging 乾淨（0 false positive）

若 review 模式不支援直接刪除，改成手動編輯 staging 檔；先 `git diff` 確認改動只刪那一條。

### 1B. 手動補搬 bug-fix archive 進 _archive/2026-04/
背景：4eb14ef / 9e6238b / 102d635 三 commits 那次 inbox prompt 還在 `docs/prompts/` top-level，沒被 archive-prompts.sh 自動搬。

步驟：
1. `ls docs/prompts/*.md` 找 top-level 殘留檔（非 `_inbox.md` 那個）
2. 確認該檔含 `## Result` block 且對應 archive commit 已存在於 git log
3. `git mv docs/prompts/<檔名> docs/prompts/_archive/2026-04/<檔名>`
4. commit: `chore: relocate stale bug-fix prompt into _archive/2026-04/`

若檔已不存在（已被搬過），跳過並在 Result 註明 "1B skipped: already archived"。

---

## Phase 2（B）— detection regex 限定 `^- ` 行匹配

### 背景
9e6238b 修了 fence detection 後，meta-text false positive（散文裡提到「no FAIL lines」這類反身字串）仍會被抓。原因：detection 沒限定行首格式。真 lesson 都是 `^- ...` bullet，散文行不是。

### 步驟
1. grep `archive-prompts.sh` + `lessons.sh` 找 detection regex 位置（看誰負責從 archived Result block 抓 lesson candidate）
2. 修改 regex：lesson 行必須以 `^- ` 開頭，排除散文段落
3. self-test：在 `/tmp/` 寫一個含 meta-text 的 fake archived prompt，跑 detection 函式，確認：
   - meta-text 散文行 → 不被抓 ✅
   - 真 `- xxx` bullet → 仍被抓 ✅
4. `bash scripts/test-bootstrap.sh` 確認回歸 PASS（應 ≥ 36/36）
5. commit: `fix: lesson detection regex restricted to ^- bullet lines`

---

## 收尾

1. `bash scripts/archive-prompts.sh` 把這份 _inbox.md archive 進 `_archive/2026-04/`
2. archived 檔尾 append `## Result` block：
   - **Status**: ✅ shipped / ⚠️ partial / ❌ blocked
   - **Verification**:
     - 1A staging cleanup: PASS / FAIL（附 `lessons.sh status` 輸出）
     - 1B archive relocate: PASS / SKIPPED / FAIL
     - 2 detection regex: PASS / FAIL（附 self-test + test-bootstrap 結果）
   - **Commits**: 列出本輪所有 commit hashes
3. osascript notification + 失敗時 `say -v Mei-Jia "卡住了"`
4. **Auto-queue 授權 = 此 sequence**，跑完 executor 必停

---

## 驗證 checklist（executor 自檢）

- [ ] `bash scripts/lessons.sh status` 顯示 staging 乾淨
- [ ] `ls docs/prompts/*.md` 只剩 `_inbox.md`（或它自己已被 archive）
- [ ] `bash scripts/test-bootstrap.sh` PASS
- [ ] detection regex self-test 通過
- [ ] commits 已 push（`git push`）

## Result

**Status**: ✅ shipped
**Commits**: 2 (excl. archive)
b5dc034 chore: relocate stale bug-fix prompt into _archive/2026-04/
946bad2 fix: lesson detection regex restricted to ^- bullet lines, exclude negated no-FAIL meta-text

**Verification**:
- 1A staging cleanup: PASS (lessons.sh count → 0 total)
- 1B archive relocate: PASS (git mv 2026-04-27-lessons-bsd-awk-and-detection-fence-fix.md)
- 2 detection regex: PASS (self-test 4/4 assertions + test-bootstrap 36/36)

**Push**: ✅ pushed to origin/main
**Blockers**: none
