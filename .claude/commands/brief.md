---
description: 印當前進度 briefing — RESUME.md 前 30 行 + 最近 commits + handoff memory
---

讀以下三個來源並合成一個 5-8 行 briefing，告訴使用者「這個 repo 現在做到哪、下一步要做什麼」：

1. `RESUME.md` 的前 30 行（如果存在）
2. `git log --oneline -5` 的輸出
3. 最新的 `project_current_handoff` 記憶（從 auto-memory 讀，如果存在）

格式：bullet list，無 preamble，無結尾總結。先列 RESUME 重點 → 再列最近 commits → 最後一句下一步建議。

如果三個來源都不存在或都是空的，回報「沒有可用的進度資訊」並提示使用者：
- 若是新 bootstrap 的專案，先填 `RESUME.md`
- 若 memory 沒有 handoff entry，請 planner 先寫一個
