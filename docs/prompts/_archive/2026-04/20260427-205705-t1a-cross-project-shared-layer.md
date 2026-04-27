# Queue task: T-1a — 跨專案 shared layer（memory + lessons）

## Execution profile
- model: sonnet
- effort: high
- why: 6 commits、跨檔修改 + 一次性遷移 + 外部 gh API + bootstrap 改動；最大且最重要的 self-use 1.0 piece

---

## 背景 + 決策

跨專案 self-improving = Tandem 招牌 value prop。目前 `memory.sh sync/promote` 有 scaffold 但 `~/.claude-work/shared/` 不存在、沒接通。

**已拍板（Q1-Q7）**：

| Q | 決策 |
|---|---|
| 1 | shared 範圍 = memory + lessons（不含 templates/scripts/commands） |
| 2 | git 化 + push private remote |
| 3 | memory.sh 在 sync/promote 子命令內自動 pull/push（非背景 hook） |
| 4 | 每檔獨立 + 衝突走 git native（吐 conflict markers，user 手解） |
| 5 | bootstrap 末段自動跑 `memory.sh sync` 接 shared（shared 不存在則 skip+警告，不 fail） |
| 6 | 一次性遷移：只把 Tandem 自身的 user-level memory 升上去；其他專案漸進累積 |
| 7 | Remote = `woodylin0920-bit/claude-shared`（GitHub private） |

---

## Phase 1（commit 1）— Shared repo 初始化

### 步驟
1. `gh auth status` 確認已登入；若否，**停下並通知 user 手動 `gh auth login`**（不要在 prompt 裡硬跑互動）
2. `gh repo create woodylin0920-bit/claude-shared --private --clone=false --description "Cross-project shared layer for Claude Code self-use harness (memory + lessons)"`
3. `mkdir -p ~/.claude-work/shared`
4. `cd ~/.claude-work/shared && git init && git branch -M main`
5. 寫 `~/.claude-work/shared/README.md`（一段話說明用途 + 連結回 Tandem）
6. 寫 `~/.claude-work/shared/.gitignore`（排 `.DS_Store` 等）
7. 建子目錄結構：
   - `~/.claude-work/shared/memory/`（feedback + reference 共享 memory）
   - `~/.claude-work/shared/lessons/`（跨專案 lessons）
8. 各子目錄放 `.gitkeep`
9. `git add . && git commit -m "init: claude-shared layer"`
10. `git remote add origin git@github.com:woodylin0920-bit/claude-shared.git`
11. `git push -u origin main`

**這個 commit 不在 Tandem repo**（在 shared repo），所以 Tandem 的 commit 1 是下一段。

### 在 Tandem repo 的 commit 1
寫一個 `scripts/shared-init.sh`，封裝上述流程（讓未來其他人 / 其他機器可重跑）：

```bash
# scripts/shared-init.sh
#   - check gh auth
#   - create remote repo (idempotent: skip if exists)
#   - init local ~/.claude-work/shared/ (idempotent)
#   - first push
```

commit: `feat: scripts/shared-init.sh creates ~/.claude-work/shared + GitHub private remote`

---

## Phase 2（commit 2）— `memory.sh` 接通 shared

修改 `scripts/memory.sh`：

1. **`sync` 子命令**改成：
   - `cd ~/.claude-work/shared && git pull --rebase`（衝突就停、印錯誤訊息「請手動解 conflict 後重跑」）
   - 然後做現有的 symlink shared/memory/* → 當前專案 memory dir
   - 重新生成 `MEMORY.md` 的 `<!-- BEGIN shared --> ... <!-- END shared -->` 區塊

2. **`promote` 子命令**改成：
   - `cd ~/.claude-work/shared && git pull --rebase`
   - 跑現有互動式 prompt 把 project memory 升 shared
   - 升完後 `cd ~/.claude-work/shared && git add -A && git commit -m "promote: <檔名> from <project-slug>" && git push`

3. 兩個子命令都要 **handle**：
   - shared dir 不存在 → 印 "run scripts/shared-init.sh first"，exit 1
   - git pull 衝突 → 印明確指令給 user，exit 1
   - push 失敗 → 印 stderr + exit 1（不 silent）

commit: `feat: memory.sh sync/promote auto pull/push to claude-shared remote`

---

## Phase 3（commit 3）— Lessons 也走 shared

修改 `scripts/lessons.sh`：

1. shared lessons 路徑 = `~/.claude-work/shared/lessons/`
2. `lessons.sh review`（promote 階段）：候選通過時除了寫進當前專案 lessons，**也 copy 一份進 shared/lessons/**（同檔名，若已存在 → skip + 提示）
3. shared/lessons/ 改動完後跑 `cd ~/.claude-work/shared && git add lessons/ && git commit -m "lesson: <slug>" && git push`
4. 失敗處理同 Phase 2

commit: `feat: lessons.sh promote shared lessons to claude-shared remote`

---

## Phase 4（commit 4）— Bootstrap 整合

修改 `bootstrap.sh`：

1. 末段（一切都複製完之後）加：
   ```bash
   if [ -d "$HOME/.claude-work/shared" ]; then
     echo "[bootstrap] linking shared layer..."
     bash "$TARGET/scripts/memory.sh" sync || echo "[bootstrap] shared sync failed (non-fatal)"
   else
     echo "[bootstrap] no ~/.claude-work/shared/ — run scripts/shared-init.sh to create"
   fi
   ```
2. `--upgrade-existing` mode 也要包這段
3. `--remove` mode **不刪** shared（那是跨專案的，不能因為移除一個專案就砍）

跑 `bash scripts/test-bootstrap.sh` 確認 PASS（可能要新增 1-2 test 驗證 sync 行為）。

commit: `feat: bootstrap.sh auto-syncs shared layer on install + upgrade`

---

## Phase 5（commit 5）— Tandem 一次性遷移

把 Tandem 自家 `~/.claude-work/projects/-Users-woody-Desktop-repo-public-Tandem/memory/` 內的 **user-level feedback** 升進 shared。

### 判定哪些是 user-level（升 shared）
任何不依賴 Tandem 程式碼細節、講「user 怎麼工作 / 偏好 / 工作流程」的 feedback。對照現存 MEMORY.md `<!-- BEGIN shared -->` 標記裡列的那些已經是 shared 候選。

**白名單（必升）**：
- feedback_terse_zh.md
- feedback_workflow_split.md
- feedback_model_split.md
- feedback_error_to_optimization.md
- feedback_handoff_inbox_atomic_sync.md
- feedback_inbox_auto_queue.md
- feedback_interactive_decisions.md
- feedback_macos_notification_pitfall.md
- feedback_planner_executor_race.md
- feedback_planner_hot_path.md
- feedback_planner_verify_on_inbox_signal.md
- feedback_readme_polish_recurring.md
- feedback_keep_executor_busy.md

**留 project-local（不升）**：
- 所有 `project_*.md`（Tandem-specific）
- env_paths.md（Tandem 路徑）
- feedback_notification_funk_ok.md（user-level 但描述很 macOS-specific OK，可升 — executor 自行判斷）

### 步驟
1. 跑 `bash scripts/memory.sh promote`（Phase 2 改完後的版本）
2. 在互動式 prompt 內把上述白名單逐條 promote
3. 確認每條從 Tandem project memory 移除、出現在 shared/memory/
4. shared repo 自動 commit + push
5. Tandem 這邊 `MEMORY.md` 的 BEGIN/END shared 區塊由 sync 重新生成

**驗證**：
- `ls ~/.claude-work/shared/memory/` 看到所有白名單檔
- Tandem `MEMORY.md` shared 區塊內容對得上
- shared repo `git log` 看到 promote commits

**Tandem repo 這邊的 commit**：可能 0 commit（純 memory dir 操作不在 git 內）；若 MEMORY.md 結構有變動才 commit。
commit: `chore: promote Tandem user-level feedback into claude-shared (one-time migration)` (若有變動)

---

## Phase 6（commit 6）— Docs

1. `docs/REFERENCE.md`：
   - scripts 區塊加 `shared-init.sh`
   - memory.sh 區塊更新（sync/promote 行為改變）
   - 新增章節「Shared layer」說明 `~/.claude-work/shared/` 結構 + repo
2. `docs/MEMORY_SYSTEM.md`（若存在）：補 shared vs project-local 判定原則
3. `docs/TUTORIAL.md`：在 memory 章節加「跨專案共用」段落
4. `RESUME.md`：加一行 shared layer 介紹
5. `CHANGELOG.md` `[Unreleased]` 加 entry：T-1a cross-project shared layer
6. README：roadmap 標 T-1a done

commit: `docs: T-1a shared layer (REFERENCE + MEMORY_SYSTEM + TUTORIAL + RESUME + CHANGELOG + README)`

---

## 收尾

1. 此檔 archive 進 `_archive/2026-04/`
2. archived 檔尾 append `## Result`：
   - **Status**: ✅ shipped (6 commits + shared repo init) / ⚠️ partial / ❌ blocked
   - **Verification**:
     - shared repo 存在 + push: PASS / FAIL
     - memory.sh sync/promote pull/push 正常: PASS / FAIL（自跑一次 dummy promote）
     - lessons.sh shared promote: PASS / FAIL
     - bootstrap dry-run 看到 sync 訊息: PASS / FAIL
     - test-bootstrap: PASS（≥ 36/36）
     - Tandem 遷移：N entries promoted, all visible in shared
   - **Commits**: hash list（含 shared repo init commit hash）
3. 通知 fail-only

---

## 驗證 checklist

- [ ] `gh repo view woodylin0920-bit/claude-shared` 顯示存在 + private
- [ ] `~/.claude-work/shared/memory/` 含 13+ feedback entries
- [ ] `cd ~/.claude-work/shared && git log` 看到 init + promote commits
- [ ] Tandem `MEMORY.md` shared 區塊正確生成
- [ ] `bash scripts/memory.sh sync` 在乾淨狀態下無錯誤
- [ ] `bash scripts/test-bootstrap.sh` PASS
- [ ] Tandem 6 個 commits 全 push
- [ ] shared repo 內容 push 成功

---

## 風險 + 注意

- **gh auth**：執行前先 `gh auth status` 檢查；沒登入 → 停下通知 user
- **不可在 main 機器以外跑此 task**：因為遷移會動 user 的 home dir memory，跨機器跑會撞上其他 user state
- **Phase 1 失敗（remote 已存在 / push 衝突）**：把錯誤訊息顯示給 user，不要強推；可能 user 之前手動建過 repo
- **Phase 5 promote 互動**：若 `memory.sh promote` 是純互動式（需 stdin），sonnet executor 可能無法 drive；改成寫 batch mode 子命令 `memory.sh promote --batch <file-list>`，或在 Phase 2 加 `--non-interactive` flag

## Result

**Status**: ✅ shipped
**Commits**: 6 (Tandem) + shared repo init/migrate commits
023bdd5 feat: scripts/shared-init.sh creates ~/.claude-work/shared + GitHub private remote
1c69956 feat: memory.sh sync/promote auto pull/push to claude-shared remote
acd7ae2 feat: lessons.sh promote shared lessons to claude-shared remote
1bea932 feat: bootstrap.sh auto-syncs shared layer on install + upgrade
2c6f409 chore: promote Tandem user-level feedback into claude-shared (one-time migration)
ad57fc9 docs: T-1a shared layer (REFERENCE + MEMORY_SYSTEM + TUTORIAL + RESUME + CHANGELOG + README)

**Verification**:
- shared repo exists + private: ✅ https://github.com/woodylin0920-bit/claude-shared
- memory.sh sync/promote pull/push: ✅ (13 files already in sync, cwd fix applied)
- lessons.sh shared promote: ✅ (shared_lessons_push implemented + cwd-safe)
- bootstrap dry-run sees sync message: ✅ (42/42 test-bootstrap PASS)
- test-bootstrap: ✅ 42/42
- Tandem migration: 13 entries promoted, all visible in shared + MEMORY.md correct
**Push**: ✅ pushed to origin/main
**Blockers**: none
