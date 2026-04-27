---
description: 讀 docs/prompts/_queue/ 目錄，依時戳順序消化所有 task
---

讀取 `docs/prompts/_queue/` 目錄，依檔名時戳（字典序 = FIFO）逐一消化所有任務。

## 執行流程（迴圈）

在每次迭代：

1. 跑 `bash scripts/auto-loop.sh next` 取下一份任務檔路徑
2. 若 exit 1（queue 空）→ 印 `auto: queue empty` → 跑 `bash scripts/auto-loop.sh notify success "loop done"` → **結束迴圈**
3. Read 該檔，**完全照其 prompt 內容執行**（commit / verify / 一般 inbox 流程），不要二次推理決策
4. 完成（或卡住）後，在該檔末尾 append `## Result` 區塊：

   ```markdown
   ## Result

   **Status**: ✅ shipped | ⚠️ blocked | ❌ failed
   **Commits**: <count>
   <git log --oneline of new commits this task, one per line>

   **Verification**: <1-2 line test/smoke output>
   **Push**: ✅ pushed to origin/main | ❌ <reason>
   **Blockers**: <description, or "none">
   ```

5. 跑 `bash scripts/auto-loop.sh archive <path>` 把該檔搬進 `_archive/YYYY-MM/`（含 Result block）
6. 判斷結果：
   - **失敗**（verification FAIL / 被 STOP block）→ 跑 `bash scripts/auto-loop.sh notify fail <task-name>` → **立即停整個迴圈**，不繼續後面任務
   - **成功** → 跑 `bash scripts/auto-loop.sh notify success <task-name>` → 回到步驟 1

## Archive commit

每份任務跑完後，把 archive 動作（步驟 5）納入一個 commit：
`chore: archive <slug> queue task + result`

然後 push。

## 邊界情況

- `_queue/` 空（只有 `.gitkeep`）：`bash scripts/auto-loop.sh next` 回傳 exit 1 → 直接結束，不通知。
- 任務內容不像 prompt（空檔或 placeholder）：跳過該檔（archive 它，Result = `❌ failed / skipped`），繼續下一份。
- `osascript` / `say` 非 macOS 環境會失敗 — `auto-loop.sh notify` 已用 `2>/dev/null || true` 包覆。
- 通知行為由 `TANDEM_AUTO_NOTIFY` env 控制（預設 `fail` = 成功靜音、失敗才響）。

## Fail-stop 原則

失敗時**不繼續跑後面任務**，避免基於壞狀態累積錯誤。留在 queue 的後續任務等 user 修復後再手動跑 `/auto`。
