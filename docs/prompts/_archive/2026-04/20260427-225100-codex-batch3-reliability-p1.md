# Queue task: Codex Batch 3 — 可靠性 P1 修

## Execution profile
model: sonnet, effort: high
參考：docs/audits/codex-2026-04-27.md

---

## Commit 1 — Notify silent fail 修

**問題**：`scripts/auto-loop.sh:56-60` 跟 `scripts/notify-blocked.sh` 跑 `osascript` / `say` 全 `2>/dev/null`，失敗時完全沒訊息。macOS 上 osascript 從 CLI 跑常因 Script Editor host 沒授權 silent fail（已記在 `feedback_macos_notification_pitfall`）。

**修法**：所有 notify 點改：
```bash
osascript -e '...' || echo "[notify] osascript failed (host permission?)" >&2
afplay /System/Library/Sounds/Glass.aiff || echo "[notify] afplay failed" >&2
say -v Mei-Jia "..." || echo "[notify] say failed" >&2
```
失敗訊息一定要到 stderr，user 才能看到「為什麼沒響」。

**驗證**：故意改錯 osascript 字串 → 確認 stderr 印出 `[notify] osascript failed`。

---

## Commit 2 — Bootstrap shared sync stderr 保留

**問題**：`bootstrap.sh:280, 611` shared sync 用 `>/dev/null 2>&1` 全吞，失敗只剩 generic WARN，user 不知道為什麼掉線。

**修法**：
- 這兩處改成 capture stderr 到變數，失敗時 echo 出來：
  ```bash
  if ! err=$(bash scripts/memory.sh sync 2>&1); then
      echo "[bootstrap] shared sync failed:" >&2
      echo "$err" | head -10 >&2
      echo "[bootstrap] continuing without shared layer" >&2
  fi
  ```
- 成功路徑保持安靜（不噴 stdout）
- 錯誤摘要限 10 行，避免洪水

**驗證**：手動 break shared remote（改 origin URL 成無效），bootstrap 應印出明確 git error 摘要。

---

## Commit 3 — Path-scoped git add（`memory.sh` + `lessons.sh`）

**問題**：`scripts/memory.sh:66` 跟 `scripts/lessons.sh:31` 用 `git add -A` 在 `~/.claude-work/shared/` repo 內，可能誤推非預期檔（user 在那目錄手動 touch 任何東西都會被吸進去）。

**修法**：
- `memory.sh`：`git add memory/*.md MEMORY.md` (只白名單路徑)
- `lessons.sh`：`git add lessons/*.md`
- 若 staging 有其他改動 → 印警告但不 commit：
  ```bash
  unstaged=$(git status --porcelain | grep -v '^[AM] memory/' | grep -v '^[AM] lessons/' || true)
  [ -n "$unstaged" ] && echo "[shared] non-tracked changes ignored:" >&2 && echo "$unstaged" >&2
  ```

**驗證**：在 `~/.claude-work/shared/` `touch evil.txt`，跑 `memory.sh promote` → `evil.txt` 不該被 commit，stderr 印警告。

---

## 收尾

archive 此檔，append `## Result`（精簡格式）。push 全部 commits。
更新 `docs/audits/codex-2026-04-27.md` 加 `[FIXED in <hash>]`。

## Result
Status: ✅ shipped
Commits: 4961256 fix(notify): surface osascript/say failures to stderr instead of silencing them
         bb8ec3c fix(memory): show shared sync errors instead of silencing them
         61ac80c fix(shared): path-scoped git add prevents accidental inclusion of untracked files
Notes: bootstrap.sh 不存在，對應修改在 memory.sh:386,517；notify 驗證 OK；path-scoped add 實裝完成
