---
description: 跑 codex 整體審查，按 templates/prompts/CODEX_AUDIT.md 格式
---

讀 templates/prompts/CODEX_AUDIT.md（如果不在當前 project 內，去 ~/Desktop/repo/public/Tandem/templates/prompts/CODEX_AUDIT.md 找模板）。

詢問 user 8 個 placeholder 值：
- PROJECT_NAME
- PROJECT_DESCRIPTION_1_SENTENCE
- COMMIT_SHA（建議用 `git log -1 --format=%h`）
- TEST_COUNT（建議跑 pytest 拿 count）
- STACK_LIST
- TRIGGER_FLOW
- FILE_LIST（production code only，不含 test_*.py）
- TARGET_USER_DESCRIPTION

把值填進 prompt template，餵給 codex（用 Skill tool 的 codex skill 或請 user 跑 terminal codex）。

把報告完整呈現給 user，最後加 verdict 對應動作建議：
- 0 P0/P1 → ship-ready
- 1-3 P0/P1 → 寫 fix prompt
- 4+ P0 → 拆批
- 一堆 P2 → REFACTOR_OPPORTUNITIES.md
