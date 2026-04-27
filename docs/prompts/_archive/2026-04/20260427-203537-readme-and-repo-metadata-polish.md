# Queue task: README + GitHub repo metadata polish (post-v0.5.0)

## Execution profile
- model: sonnet
- effort: low
- why: v0.5.0 released + Phase A/B/C ship + /auto 上線後例行檢查；可能 0 改動

---

## 背景

per `feedback_readme_polish_recurring`：release / 大功能 ship 後 planner 要主動檢查 README + GitHub metadata 是否 stale。剛 ship `/auto` mode 是大功能 → 觸發此輪。

---

## 任務

### Phase 1 — README.md 檢查
1. 讀 `README.md` 全文
2. 檢查 stale 項目：
   - Version badge / 文字是否 v0.5.0
   - Roadmap / 進度區塊是否反映 Phase A/B/C done + v0.5.0 released
   - 命令清單是否含 `/auto`（剛上線）
   - Quickstart 範例是否仍正確（檔名、路徑、命令名）
   - 死連結 / 對不存在檔案的引用
3. 有 stale → 修正；無 → 跳過此 phase

### Phase 2 — GitHub repo metadata 檢查
1. `gh repo view woodylin0920-bit/Tandem --json description,topics,homepageUrl` 看現況
2. 評估：
   - description 是否反映現狀（self-use solo-dev workflow harness for Claude Code, planner/executor split）
   - topics 是否涵蓋 `claude-code` / `workflow` / `solo-dev` / `planner-executor` 之類關鍵字
   - homepage URL 是否設（可選）
3. 需要更新就跑 `gh repo edit` 修；無就跳過

---

## 收尾

1. 若有改動 → commit message: `docs: README + repo metadata polish post-v0.5.0 + /auto`
2. 若無改動 → **不 commit，但仍 archive 此 task 並在 Result 註明 "no changes needed, both checks PASS"**
3. `bash scripts/archive-prompts.sh` 把此檔搬進 `_archive/2026-04/`（注意：archive-prompts.sh 可能只認 `_inbox.md` → 若不支援 queue 檔，改手動 `git mv`）
4. archived 檔尾 append `## Result` block：
   - **Status**: ✅ shipped (X changes) / ✅ no-op (PASS, no changes needed) / ❌ blocked
   - **Verification**:
     - README check: PASS / N stale items fixed
     - repo metadata check: PASS / updated
   - **Commits**: hash list 或 "(none — no changes)"
5. 通知依 `TANDEM_AUTO_NOTIFY` env（預設 fail-only，成功靜音）

---

## 驗證 checklist

- [ ] README 與當前 state 一致
- [ ] gh repo metadata 正確
- [ ] 此檔已從 `_queue/` 移出
- [ ] 若有 commit 已 push

## Result

**Status**: ✅ shipped (2 changes)
**Commits**: 1
f29435c docs: README + repo metadata polish post-v0.5.0 + /auto

**Verification**:
- README check: 2 stale items fixed (slash commands list missing /auto; Roadmap missing Phase D /auto entry)
- repo metadata check: PASS (description + topics accurate, no changes needed)
**Push**: ✅ pushed to origin/main
**Blockers**: none
