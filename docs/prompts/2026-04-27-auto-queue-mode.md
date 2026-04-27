# Inbox: `/auto` mode — queue-based executor loop

## Execution profile
- model: sonnet
- effort: medium-high
- why: 新功能 4 commits（slash + script + bootstrap + docs）；無破壞性、純加法、與現有 `/inbox` 並存

---

## 背景

Planner 在規劃時 executor terminal 常閒置。設計 `/auto` 讓 planner 可一次丟多份任務進 queue 目錄，executor 自動依序消化。決策已拍板（Q1-Q7）：

| 決策 | 選擇 |
|---|---|
| Queue 模型 | `docs/prompts/_queue/` 目錄（多檔） |
| 停止條件 | queue 空就停（不輪詢） |
| 失敗處理 | fail-stop，留檔在 queue，響通知 |
| 檔名 | `YYYYMMDD-HHMMSS-slug.md`（時戳 FIFO） |
| 相容性 | `_inbox.md` + `/inbox` 保留，純加法 |
| 通知 | 預設成功靜音、失敗響；env `TANDEM_AUTO_NOTIFY=all\|fail\|none` 切換 |
| Archive | 同 `/inbox`：搬 `_archive/YYYY-MM/` + Result block |

---

## Phase 1 — `scripts/auto-loop.sh`

建立 `scripts/auto-loop.sh`，行為：

1. **掃 queue**：`ls docs/prompts/_queue/*.md 2>/dev/null | sort`（檔名時戳 → 字典序 = FIFO）
2. **若空** → 印 `auto: queue empty, exiting` → exit 0
3. **取最舊一份**作為當前任務 `CURRENT`
4. **執行**：把 `CURRENT` 內容當作 prompt 給 Claude Code 跑（**注意**：這個 script 不直接 spawn claude；而是被 `/auto` slash command 在 Claude 的 turn loop 內呼叫，由 Claude 讀檔後依內容操作）
   - 因此實際的「跑」邏輯放在 `.claude/commands/auto.md` 的 instructions，script 只負責 queue 管理
   - script 提供子命令：
     - `auto-loop.sh next` → echo 下一份檔路徑（無則 exit 1）
     - `auto-loop.sh archive <path>` → 跑 `archive-prompts.sh` 把該檔搬走
     - `auto-loop.sh notify <success|fail> <task-name>` → 依 `TANDEM_AUTO_NOTIFY` env（預設 `fail`）決定 osascript / Glass / `say -v Mei-Jia "卡住了"`
     - `auto-loop.sh status` → 印 queue 狀態（剩幾份 + 最舊檔名）
5. 確保 `_queue/` 目錄存在（含 `.gitkeep`）

**通知邏輯**：
```bash
mode="${TANDEM_AUTO_NOTIFY:-fail}"
case "$mode|$result" in
  all|*|fail|fail) osascript + Glass + (fail ? say "卡住了" : nil) ;;
  none|*) ;;
  fail|success) ;;  # silent
esac
```

commit: `feat: scripts/auto-loop.sh queue management for /auto mode`

---

## Phase 2 — `.claude/commands/auto.md`

新 slash command。Instructions 大致：

```
讀 docs/prompts/_queue/ 目錄，依時戳順序消化所有 task：

迴圈：
1. 跑 `bash scripts/auto-loop.sh next` 取下一份檔路徑
2. 若 exit 1（queue 空）→ 印 "auto: queue empty"，跑 `notify success "loop done"` 後結束
3. Read 該檔，依其 prompt 內容執行（commit / verify / 一般 inbox 流程）
4. 跑完後在該檔尾 append `## Result` block（同 /inbox 慣例）
5. 跑 `bash scripts/auto-loop.sh archive <path>` 搬進 `_archive/YYYY-MM/`
6. 若該 task 失敗（verification FAIL / 被 block） → 跑 `notify fail <task-name>` → **立即停整個 loop**，留檔在 queue
7. 若該 task 成功 → 跑 `notify success <task-name>`（依 env 預設靜音）→ 回到步驟 1

每份 task 的 commit / push / verification 規則同 `/inbox`。
失敗 fail-stop = 不繼續跑後面任務（避免基於壞狀態繼續）。
```

commit: `feat: /auto slash command for queue-based executor loop`

---

## Phase 3 — `bootstrap.sh` 整合

修改 `bootstrap.sh`：
1. 複製 `.claude/commands/auto.md` 到目標專案
2. 複製 `scripts/auto-loop.sh` 到目標專案
3. 建立 `docs/prompts/_queue/.gitkeep`
4. `--upgrade-existing` mode 也要包含上述 3 項

跑 `bash scripts/test-bootstrap.sh` 確認 PASS（應從 36/36 升到 ~39/39，每項 +1 test）。
若不想擴測試，至少跑 dry-run 確認檔案出現。

commit: `feat: bootstrap.sh installs /auto command + auto-loop.sh + _queue/`

---

## Phase 4 — docs 更新

1. `docs/REFERENCE.md`：commands 區塊加 `/auto`，scripts 區塊加 `auto-loop.sh`
2. `docs/TUTORIAL.md`：在 `/inbox` 章節後加「Auto mode（多任務 queue）」小節，說明：
   - 何時用 `/auto`（planner 想丟一批小任務、規劃時不想閒置 executor）
   - 檔名時戳格式
   - 失敗 fail-stop + 通知行為
   - `TANDEM_AUTO_NOTIFY` env 切換
3. `RESUME.md`：在 "How to use" 區塊加一行 `/auto` 介紹
4. `CHANGELOG.md` `[Unreleased]` 加 entry（不 cut version，等下次 release）

commit: `docs: REFERENCE + TUTORIAL + RESUME + CHANGELOG document /auto mode`

---

## 收尾

1. `bash scripts/archive-prompts.sh` 把這份 _inbox.md archive 進 `_archive/2026-04/`
2. archived 檔尾 append `## Result` block：
   - **Status**: ✅ shipped / ⚠️ partial / ❌ blocked
   - **Verification**:
     - Phase 1 auto-loop.sh: 各子命令 PASS / FAIL
     - Phase 2 /auto slash: 檔已建 PASS
     - Phase 3 bootstrap: dry-run / test-bootstrap PASS
     - Phase 4 docs: 4 檔已更新 PASS
     - smoke test: 在 `_queue/` 放 1 份 dummy task（內容：寫 `/tmp/auto-smoke-ok` 檔），跑 `/auto`，確認檔被消化 + archive + queue 變空 + 不響通知（success silent）
   - **Commits**: 列出本輪所有 commit hashes
3. notify：成功靜音、失敗 `say -v Mei-Jia "卡住了"` + osascript（依預設 fail-only）
4. push 所有 commits

---

## 驗證 checklist（executor 自檢）

- [ ] `_queue/` 目錄存在 + `.gitkeep` committed
- [ ] `bash scripts/auto-loop.sh next` 在空 queue → exit 1
- [ ] `bash scripts/auto-loop.sh status` 印出有意義輸出
- [ ] `/auto` slash 檔語法正確（YAML frontmatter + instructions）
- [ ] bootstrap.sh dry-run 看到新檔被複製
- [ ] smoke test：dummy task 跑通完整 loop（next → 跑 → archive → queue empty → exit）
- [ ] commits 已 push

## Result

**Status**: ✅ shipped
**Commits**: 4
336d257 feat: scripts/auto-loop.sh queue management for /auto mode
8f5eb9a feat: /auto slash command for queue-based executor loop
1e63178 feat: bootstrap.sh installs /auto command + auto-loop.sh + _queue/
7a503f9 docs: REFERENCE + TUTORIAL + RESUME + CHANGELOG document /auto mode

**Verification**:
- Phase 1 auto-loop.sh: next/archive/notify/status subcommands PASS
- Phase 2 /auto slash: .claude/commands/auto.md created PASS
- Phase 3 bootstrap: test-bootstrap.sh 40/40 PASS
- Phase 4 docs: REFERENCE + TUTORIAL + RESUME + CHANGELOG updated PASS
- smoke test: dummy task next→execute→archive→queue empty→notify(silent) PASS

**Push**: ✅ pushed to origin/main (pending final archive commit)
**Blockers**: none
