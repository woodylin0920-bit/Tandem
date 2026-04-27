# Queue task: Codex Batch 2 — 並發 P1 修

## Execution profile
model: sonnet, effort: high
參考：docs/audits/codex-2026-04-27.md

---

## Commit 1 — Queue 原子鎖（防雙 executor 撞同檔）

**問題**：`scripts/auto-loop.sh:19,40` `next` 子命令直接讀 `_queue/*.md` 第一個，兩個 executor 同時跑會抓到同一檔重複執行。

**修法**：
1. 建立 `docs/prompts/_queue/.running/` 目錄（commit 加 `.gitkeep`）
2. `next` 子命令改成原子 `mv`：
   ```bash
   target=$(ls _queue/*.md 2>/dev/null | grep -v gitkeep | sort | head -1)
   [ -z "$target" ] && exit 0
   slug=$(basename "$target")
   mv "$target" "_queue/.running/$slug" 2>/dev/null || exit 0  # race lost
   echo "_queue/.running/$slug"
   ```
   `mv` 是 atomic（同一檔系），race 輸的 executor 自然拿不到。
3. `archive` 子命令：source 從 `.running/` 取，移到 `_archive/YYYY-MM/`
4. `.gitignore` 確保 `.running/*.md` 不被誤 commit（保留 `.gitkeep`）

**驗證**：兩 terminal 同時 `bash scripts/auto-loop.sh next` → 只有一個拿到 path，另一個空輸出。

---

## Commit 2 — `/auto` Ctrl+C trap

**問題**：`.claude/commands/auto.md:14-26` 沒處理中斷訊號，user Ctrl+C 時 task 留在 `.running/` 永遠卡住。

**修法**：在 `auto.md` 加 `## Interrupt handling` 段：
- executor 拿到 task 後設 trap：收 INT/TERM 時，把當前 `.running/x.md` 改成 append `## Result\nStatus: ⚠️ blocked: interrupted by user\nCommits: (partial)\nNotes: 中斷於 <step>` 並 archive 回 `_archive/`，然後 exit
- queue 剩餘任務保留不動（fail-stop 行為一致）

scripts 層配合：`auto-loop.sh` 加 `recover` 子命令，掃 `.running/` 若有殘檔（previous session 沒清乾淨），印警告並列出，user 手動處理。

**驗證**：手動測 1 次 — `/auto` 跑到一半 Ctrl+C，確認 `.running/` 空、`_archive/` 多一份 `⚠️ blocked: interrupted`。

---

## Commit 3 — Executor mutex（`/inbox` + `/auto` 互斥）

**問題**：`/inbox` 跟 `/auto` 同時跑會雙寫 commit/push 互撞。

**修法**：
1. `scripts/executor-lock.sh` helper：
   ```bash
   LOCK="$REPO/.git/tandem-executor.lock"
   exec 9>"$LOCK"
   flock -n 9 || { echo "[executor] another session running, abort" >&2; exit 1; }
   trap 'flock -u 9; rm -f "$LOCK"' EXIT
   ```
2. `auto-loop.sh` 開頭 source 此 helper
3. `.claude/commands/inbox.md` 加段落：「executor 開跑前先 `bash scripts/executor-lock.sh` 取鎖；取不到立刻停」
4. macOS 沒原生 `flock` — 改用 `mkdir`-based 鎖：`mkdir "$LOCK.d" 2>/dev/null || { echo "[executor] another session running" >&2; exit 1; }`，trap EXIT `rmdir`

**驗證**：兩 terminal 同時 `/auto` → 第二個立刻 abort 印 message，不執行任何 commit。

---

## 收尾

archive 此檔，append `## Result`（精簡格式）。push 全部 commits。
更新 `docs/audits/codex-2026-04-27.md` 在 fixed 條目旁加 `[FIXED in <hash>]`。

## Result
Status: ✅ shipped
Commits: 2c13d06 fix(queue): atomic mv-based lock to prevent double-executor task collision
         cee23d7 fix(auto): add interrupt handling section and recover guidance
         9df4302 fix(concurrency): executor mutex prevents /auto + /inbox from running simultaneously
Notes: 全 3 commits 通過；executor-lock.sh acquire/release/stale 驗證 OK；audit 標記完成
