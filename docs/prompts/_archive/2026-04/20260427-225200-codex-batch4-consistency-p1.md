# Queue task: Codex Batch 4 — 一致性 P1 修

## Execution profile
model: sonnet, effort: high
參考：docs/audits/codex-2026-04-27.md

---

## Commit 1 — Lessons staging path 統一常數

**問題**：`scripts/archive-prompts.sh:11`、`scripts/statusline.sh:36`、`scripts/lessons.sh:12` 三處各自寫 lessons-staging path，已經出現過不一致 bug。

**修法**：
- 建 `scripts/_paths.sh`（source 用 helper）：
  ```bash
  TANDEM_LESSONS_STAGING="${TANDEM_LESSONS_STAGING:-$HOME/.claude-work/_shared/lessons-staging.md}"
  TANDEM_SHARED_DIR="${TANDEM_SHARED_DIR:-$HOME/.claude-work/shared}"
  export TANDEM_LESSONS_STAGING TANDEM_SHARED_DIR
  ```
- `archive-prompts.sh` / `statusline.sh` / `lessons.sh` 開頭 `source "$(dirname "$0")/_paths.sh"`
- 三處 hardcode path 換成 `$TANDEM_LESSONS_STAGING`
- 確認 path 收斂到「最多檔案在用的那個」（檢查現有 staging file 實體位置，避免改成空路徑）

**驗證**：grep 三檔不再出現 hardcode path；`bash scripts/lessons.sh count` + `bash scripts/statusline.sh` 都正常跑。

---

## Commit 2 — Result format detector dual support

**問題**：`scripts/archive-prompts.sh:40` detector 抓 `Status:` 但新 slim template (`c7bb686`) 寫 `**Status**:`（粗體），舊 archive 用 `**Status**: ✅` 格式。dual 不支援會漏抓。

**修法**：
`archive-prompts.sh` 抓 Status 的 grep regex 改成同時支援：
```bash
grep -m1 -E '^(\*\*Status\*\*|Status):' "$file"
```
其他 detector（FAIL / blocked / ❌）位置保持。

**驗證**：手寫兩個 fixture（一個 `Status: ✅`、一個 `**Status**: ✅`），兩個都該被 archive flow 抓到。

---

## Commit 3 — Statusline integer expression 修

**問題**：`scripts/statusline.sh:38-39` `n_lessons=$(grep -c ... || echo 0)` 在 grep 沒輸出時 `n_lessons` 變多行 `"0\n0"`，下一行 `[ "$n_lessons" -gt 0 ]` 噴 `integer expression expected` stderr。

**修法**：
```bash
n_lessons=$(grep -c '^<!-- BEGIN entry ' "$STAGING" 2>/dev/null)
n_lessons=${n_lessons:-0}
```
不用 `|| echo 0` 短路，改用 default-value expansion。

**驗證**：staging 不存在或為空時跑 statusline，stderr 應乾淨無 `integer expression`。

---

## Commit 4 — `/auto` fail-stop 文字統一 + queue 空通知矛盾

**問題**：
- `auto.md:25-26` 寫 fail-stop，但 `:38,44` 又寫「failed/skipped 後繼續」自打
- `auto.md:12 vs :37` queue 空通知規格自相矛盾

**修法**：通讀 `auto.md` 統一：
- fail-stop 規範：任務 `Status: ❌` 或 verification FAIL → executor 立即 archive + 停下，不取下一檔；queue 剩餘任務保留
- queue 空通知：依 `TANDEM_AUTO_NOTIFY` env，`fail` 預設 = 成功靜默、失敗響；queue 空就是「全成功」，不額外通知（避免冗餘）
- 移除矛盾段落，把單一規格集中在 `## Stopping conditions` 段

`auto-loop.sh` 行為對齊：archive 失敗 → exit 1；任務 `Status: ❌` detect → exit 1。

**驗證**：手動造一個 `Status: ❌` task，跑 `/auto` → 該 task archive、queue 剩餘檔保留、executor 停下。

---

## 收尾

archive 此檔，append `## Result`（精簡格式）。push 全部 commits。
更新 `docs/audits/codex-2026-04-27.md` 加 `[FIXED in <hash>]`。

## Result
Status: ✅ shipped
Commits: f648612 fix(paths): unify lessons-staging path via _paths.sh constants
         aa31a87 fix(archive): status detector supports both plain and bold Status format
         318fd3f fix(statusline): eliminate integer expression expected stderr noise
         b10d9ae fix(auto): resolve fail-stop and queue-empty notification contradictions
Notes: 4 commits；statusline 和 lessons count 輸出清潔驗證 OK；grep -c set -e 相容性 bug 同時修掉
