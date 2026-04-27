---
description: 讀 docs/prompts/_inbox.md 的 prompt 開工，完成後 append Result + 通知
---

讀取 `docs/prompts/_inbox.md` 的完整內容，把它當作這次對話的 prompt 開始執行。

## 執行流程

1. `cat docs/prompts/_inbox.md` 看完整 prompt
2. 完全照 prompt 開工（不要二次推理 prompt 的決策，那些已由規劃端鎖定）
3. 全部 commit + push 完成後（或卡住時），執行**收尾流程**：

   a. 把 `docs/prompts/_inbox.md` 的內容**搬移**到 `docs/prompts/<YYYY-MM-DD-descriptive-slug>.md`
   b. 在搬移後的檔案**末尾** append 一個 `## Result` 區塊：

      ```markdown
      ## Result
      Status: ✅ shipped | ⚠️ blocked | ❌ failed
      Commits: <git log --oneline of new commits, one per line>
      Notes: <一行 verification 摘要 or 空>
      ```

   c. 清空 `docs/prompts/_inbox.md` 為單一 newline
   d. 把 a/b/c 全部納入**最後一個 commit**（subject: `chore: archive <slug> inbox prompt + result`）並 push

4. **最後**：透過 Bash tool 觸發 macOS 通知：

   - **成功**：
     ```
     osascript -e 'display notification "✅ <count> commits — <slug>" with title "Tandem · inbox done" sound name "Glass"'
     ```
   - **卡住 / 失敗**：
     ```
     osascript -e 'display notification "⚠️ blocked — see _inbox.md" with title "Tandem · inbox blocked" sound name "Funk"'
     say -v Mei-Jia "卡住了" 2>/dev/null || true
     ```

5. 回報給使用者：1-2 句繁中，包含 archive 檔路徑 + status，不再重複貼整段 git log（已在 archive 裡）。

## 邊界情況

- `_inbox.md` 空的或內容不像 prompt：跟使用者確認，**不要**觸發通知或建立 archive 檔。
- 中途卡住（hard constraint 違反 / test fail / push reject）：照 prompt 的 STOP 規則停下，**仍然執行 3b（Status: ⚠️ blocked）+ 3c + 4 通知**，使用者要收到訊息才知道要看 inbox。
- `osascript` / `say` 在非 macOS 環境會失敗 — 用 `2>/dev/null || true` 包起來，不要因此中斷流程。
