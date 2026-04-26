---
description: 跑 phase 過 gate 標準（pytest + benchmark + verdict）
---

跑下面 3 個 gate，全綠才算 phase 過：

1. **pytest**
   ```
   ~/venvs/$(basename $PWD)-venv/bin/pytest -v
   ```
   通過條件：所有 test passed，count 符合或超過 baseline。

2. **benchmark**（如果有）
   ```
   ./venv/bin/python benchmark.py
   ```
   通過條件：cold/warm 在 SLO 內。SLO 從 README 抓。

3. **last commit 是否乾淨 push 到 remote**
   ```
   git log @{u}..HEAD  # 應為空
   ```

呼叫者責任：跑前讓 user 確認 phase 目標 SLO，跑後給「過 gate / 沒過」verdict。

過 gate → 寫 RESUME.md 新區塊 + 決定下一步。
沒過 → 列出哪一條失敗 + 預期 vs 實際數字。
