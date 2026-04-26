# Codex Audit

woody-harness 把 codex consult-mode 抽成 reusable audit pattern。

## 為什麼要 codex

- 獨立第二意見（codex = OpenAI，跟我們用的 Anthropic 是不同系統）
- 對「結構漏洞」「安全 hole」抓得比 self-review 更徹底
- 在 ship 前必跑，因為 self-review 容易盲點

## 何時跑

- Phase 完工前（架構 review）
- ship 前（最後安全 net）
- user 回報怪事後（怎麼可能會這樣？→ 第二雙眼）

## 怎麼跑

1. 看 templates/prompts/CODEX_AUDIT.md 拿 prompt template
2. 填 placeholder
3. 跑 codex（命令列 `codex` 或 Claude Code Skill tool）
4. 報告貼回 planning session
5. Verdict 對應動作（看 CODEX_AUDIT.md 末尾表格）

## 為什麼分 codex audit + safety audit

- codex audit = 一般 review，找 bug / leak / SLO 偏離
- safety audit = 針對 silent fail / accessibility 風險的專門 review

兩個獨立跑，因為 lens 不同。一般 audit 標 P2 在 safety audit 可能升 P0。

## 真實案例：omni-sense 2026-04-27

跑 codex consult mode 7 面向 audit → 6 個 P0：
1. OCR prompt injection
2. mic/Ollama/camera silent fail
3. log_event 遞迴 crash
4. 沒 watchdog
5. TTS path 沒走錯誤反饋
6. NamedTemporaryFile leak

修補後 pytest 從 62 → 69，verdict not_ready → ready_pending_smoke。
