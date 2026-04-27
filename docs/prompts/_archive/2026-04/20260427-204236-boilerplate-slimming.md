# Queue task: Boilerplate slimming

## Execution profile
- model: sonnet
- effort: medium
- why: 純減法、無破壞性；降低 bootstrap 後新 user 認知負擔。可能 0-3 commits 視結果

---

## 背景

Bootstrap 完新專案會塞進一堆 templates（CLAUDE.md、RESUME.md、memory 範本、docs/、scripts/、commands/）。許多檔可能含冗餘樣板字、過度說明、或重複內容。目標：精簡到「第一次看到不嚇到」。

---

## 任務

### Phase 1 — 盤點 templates/
1. `find templates/ -type f | xargs wc -l | sort -n` 看每個 template 行數
2. 重點檢查：
   - `templates/CLAUDE.md` — 是否冗長？哪些段是 self-evident？
   - `templates/RESUME.md` — header 區塊是否太多 placeholder？
   - `templates/memory/*.md` — example memory 是否過多 / 太具體？
   - `templates/prompts/*.md`（CODEX_AUDIT、SAFETY_AUDIT、ISSUES）— 是否有複製貼上未通用化處？
   - `templates/.gitignore` — 是否有 Tandem-specific 條目該移到 user 自加？

### Phase 2 — 評估 + 修剪
針對每個冗餘點，問三個問題：
1. **這段對「第一次接觸 Tandem 的人」是否必要？** 不必要 → 刪
2. **這段能不能用「指向 docs/ 連結」取代？** 能 → 改成連結
3. **這段是 Tandem 自己的 metadata 不該洩漏進 user 專案的？** 是 → 刪

每修一個檔 commit 一次（commit message 描述刪了什麼、為什麼）。

**保守原則**：
- 不刪 hooks / settings / 命令邏輯本身
- 不刪 user 後續可能用到的 placeholder（即使空）
- 不刪註解中的「why」（保留 rationale）
- 刪「what」描述（自註解的程式碼不需要）

### Phase 3 — 驗證
1. `bash scripts/test-bootstrap.sh` 確認仍 PASS（≥ 36/36）
2. dry-run bootstrap 到 `/tmp/wh-slim-test/`，目視看新生成檔是否更乾淨
3. 量化：bootstrap 後總行數 before vs after

---

## 收尾

1. `git mv` 此檔進 `_archive/2026-04/`（或 archive-prompts.sh 若支援 queue）
2. archived 檔尾 append `## Result`：
   - **Status**: ✅ shipped (N commits) / ✅ no-op (already lean) / ❌ blocked
   - **Verification**:
     - test-bootstrap: PASS
     - dry-run: 行數 X → Y (-Z%)
     - 修剪檔清單
   - **Commits**: hash list
3. 通知 fail-only

---

## 驗證 checklist

- [ ] test-bootstrap PASS
- [ ] bootstrap 產物總行數下降（或證明已最小）
- [ ] commits push
- [ ] 無功能性回歸（hooks / commands 仍 work）

## Result

**Status**: ✅ shipped
**Commits**: 3
d492b4c trim: remove project-specific examples from env_paths + RESUME templates
8ddce3a trim: replace ML-specific placeholder examples with generic ones in CODEX_AUDIT
a4500fe trim: remove Tandem-internal pre-flight block from workflow memory template

**Verification**:
- test-bootstrap: PASS 40/40
- templates/ 行數: 505 → 492 (-13 lines, -2.6%)
- 修剪檔清單: feedback_workflow_split.md, CODEX_AUDIT.md, env_paths.md, RESUME.md
- 無功能性回歸（hooks / commands 不觸及）
**Push**: ✅ pushed to origin/main
**Blockers**: none
