# Queue task: Codex Batch 5 — P2 polish

## Execution profile
model: sonnet, effort: high
參考：docs/audits/codex-2026-04-27.md

---

## Commit 1 — notify-blocked cooldown + singleton

**問題**：`scripts/notify-blocked.sh:5` 每次背景起 `afplay` 無節流，連續事件可疊聲。

**修法**：
```bash
COOLDOWN=60  # seconds
LAST="$HOME/.claude-work/.notify-last"
now=$(date +%s)
last=$(cat "$LAST" 2>/dev/null || echo 0)
[ $((now - last)) -lt $COOLDOWN ] && exit 0
echo "$now" > "$LAST"

# singleton: prevent overlapping afplay
LOCK="$HOME/.claude-work/.notify.lock"
exec 9>"$LOCK"
mkdir "$LOCK.d" 2>/dev/null || exit 0  # macOS fallback
trap 'rmdir "$LOCK.d"' EXIT
afplay /System/Library/Sounds/Funk.aiff &
osascript -e '...' || echo "[notify] osascript failed" >&2
```

**驗證**：連按兩次觸發 → 第二次 60s 內靜默；同時兩個 instance → 第二個 exit 0 不疊聲。

---

## Commit 2 — shared-init owner 動態取得

**問題**：`scripts/shared-init.sh:7,21-25` GitHub owner hardcode `woodylin0920-bit`，其他 user 跑 bootstrap 會失敗。

**修法**：
```bash
OWNER="${TANDEM_SHARED_OWNER:-$(gh api user --jq .login 2>/dev/null)}"
if [ -z "$OWNER" ]; then
    echo "[shared-init] cannot determine owner — set TANDEM_SHARED_OWNER or run 'gh auth login'" >&2
    exit 1
fi
```
所有 hardcode `woodylin0920-bit` 換成 `$OWNER`。

**驗證**：unset env + 已登入 gh → 自動抓 login；未登入 → 印明確 error 不繼續。

---

## Commit 3 — `_archive/` 月度 retention helper

**問題**：`docs/prompts/_archive/` 無 retention，年累積會肥。

**修法**：新建 `scripts/archive-prune.sh`：
- 列 `_archive/` 各月份目錄，超過 N 個月（default 3）的整月打包成 `_archive/legacy/<YYYY-MM>.tar.gz`，原目錄刪掉
- 不自動跑，README/REFERENCE 提一下手動觸發
- argparse: `--keep-months N`、`--dry-run`

**驗證**：dry-run 印出將打包的目錄；真跑後檢查 tar.gz 完整 + 原目錄消失。

---

## Commit 4 — Statusline mtime cache

**問題**：`scripts/statusline.sh` 1Hz 全檔掃描（git log + sed + grep + ls），每秒都跑 ~50ms，閒置浪費。

**修法**：
- cache file `~/.claude-work/.statusline-cache`：第一行 `<input-mtime-sum>`，第二行起 cached output
- 計算 input mtime sum：`_inbox.md` + `_queue/` 目錄 mtime + 最新 `docs/prompts/[0-9]*.md` mtime + `.git/HEAD` mtime
- 若 sum 跟 cache 第一行一致 → 直接 cat cache 第二行，return
- 否則跑原本邏輯，產出後寫 cache

**驗證**：連跑 5 次 statusline → 第一次 ~50ms，後續 ~5ms（time 印證）；改 _inbox.md 後立刻反映新狀態。

---

## Commit 5 — `/brief` handoff generator at `/inbox` close

**問題**：`brief.md:9` 依賴 `project_current_handoff` memory 但無穩定產生器，user 必須手動寫，常 stale。

**修法**：
- `.claude/commands/inbox.md` 收尾步驟加：archive 完成後，自動 update `project_current_handoff.md` memory，內容：
  - 最後 commit SHA + subject
  - 此次 round Status + Commits 摘要
  - `_inbox.md` 狀態（empty / queued）
  - 一句 next-step 建議（從 Result block Notes 抓）
- 寫 helper `scripts/handoff-update.sh` 讓 inbox flow 收尾呼叫
- 路徑：`~/.claude-work/projects/<slug>/memory/project_current_handoff.md`，frontmatter `name`/`description` 也更新

**驗證**：手動跑一輪 inbox → 確認 handoff memory 自動更新到當輪狀態；新 session `/brief` 讀到的是最新。

---

## 收尾

archive 此檔，append `## Result`（精簡格式）。push 全部 commits。
更新 `docs/audits/codex-2026-04-27.md` 加 `[FIXED in <hash>]`，整體 verdict 重評（P0 0/2、P1 0/10、P2 0/5 → 應翻 ship-ready）。

跑完此批 → 整個 audit 清掉，可以準備 cut v0.6.0。

## Result
Status: ✅ shipped
Commits: 82ebd31 fix(notify): add 60s cooldown and singleton lock to notify-blocked.sh
         2ed3f44 fix(shared-init): determine GitHub owner dynamically via gh api user
         0e7c780 feat(archive): add archive-prune.sh for monthly retention compaction
         7ccaa8b perf(statusline): mtime-based cache to avoid redundant 1Hz full scans
         a5a29b8 feat(handoff): auto-update project_current_handoff.md at inbox close
Notes: 全 5 commits；notify cooldown 驗證 OK；handoff-update smoke test OK；audit verdict 翻 ship-ready
