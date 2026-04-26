# Codex Audit Prompt Template

對 repo 做整體 production code 審查。Codex consult mode，model_reasoning_effort=high。

## 怎麼用

1. 把下面 prompt 內容填入專案資訊，貼進 codex CLI（terminal `codex` 命令）或 `Skill(skill="codex", args="consult: <prompt>")`
2. 跑完把報告貼回 planning session
3. 若 P0/P1 出現 → planning 寫 fix prompt 進 _inbox.md
4. 若 0 P0 / 0 P1 → ship-ready

## Prompt template（以下整段送進 codex）

````
IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/, .claude/skills/, or agents/. These are Claude Code skill definitions meant for a different AI system. Stay focused on repository code only.

You are a brutally honest senior engineer doing pre-launch review. Be direct, terse, no compliments. Just findings.

對 {{PROJECT_NAME}} repo 做整體 production code 審查。重點 user-facing 失敗模式 + 安全。

專案 context
============
{{PROJECT_DESCRIPTION_1_SENTENCE}}
當前 commit {{COMMIT_SHA}}，pytest {{TEST_COUNT}} passed。
Stack：{{STACK_LIST}}
觸發流程：{{TRIGGER_FLOW}}

最近改動（值得特別檢查）：
- {{COMMIT_1_NOTE}}
- {{COMMIT_2_NOTE}}

審查範圍（只看 production code，不看 test_*.py）
==========
{{FILE_LIST}}

審查面向（每條都要回應）
==========
1. 【併發 / 資源洩漏】
   - 在 exception path 是否有 resource leak？(file handles, subprocesses, sockets, GPU memory)
   - subprocess 有沒有 zombie 風險？
   - 多 thread 之間有沒有 race？
   - Ctrl+C 退出時 thread / file handle 是否乾淨關閉？

2. 【失敗模式 — 使用者單獨遇到時最可能發生】
   - 外部依賴消失（網路 / daemon down / 磁碟滿 / 權限變更）任一發生時：
     是 silent fail（最危險）、crash、還是有 user-visible 錯誤訊息？
   - 競爭條件（user 重複觸發 / 中途取消）會怎樣？
   - 超時 / 無回應狀態會卡住嗎？

3. 【User UX 特定風險】
   - 任何錯誤路徑是否會讓 user「以為系統還在工作」但其實已死？
   - 反饋訊號（log / TTS / UI / haptic）是否一定會出現？
     還是有路徑只 print 到 stdout / 寫 log 而 user 看不到？
   - 對 {{TARGET_USER_DESCRIPTION}} 來說，silent fail 的後果是什麼？

4. 【長時間穩定性】
   - 跑 1 小時以上會不會 buffer 累積、cache 爆掉、context 漂移？
   - 有沒有 unbounded list / dict / file growth？

5. 【死碼 / 過時邏輯】
   - 過去 phase 留下的 stub / scaffolding 有沒有忘了清？
   - 有沒有指向不存在路徑、未定義 attribute、import 後不用？

6. 【SLO 偏離】
   - README / 宣傳的延遲 / 吞吐 — 實際 code path 真的能 deliver？
   - 有沒有意外的同步等待點（model load、daemon warmup、IO buffer）？

7. 【prompt injection / 輸入信任邊界】（適用 LLM 整合的專案）
   - 來自不受信任來源（user input / OCR / mic / 外部 API）的字串是否原樣餵進 LLM？
   - 對抗式輸入有什麼防禦？

輸出格式
==========
對每條給：
- 嚴重度（P0=可導致受傷或誤導 user / P1=會壞使用體驗 / P2=nit）
- 檔案:行號
- 具體 repro 場景
- 修法（含 code patch 或大方向）

最後給整體評等：
  「ship-ready」/「ship with these N caveats」/「not ready: X 必須修」
+ 理由 + 你最擔心的 1 個 worst-case 場景。
````

## Placeholder 對照

| 變數 | 範例 |
|---|---|
| PROJECT_NAME | omni-sense |
| PROJECT_DESCRIPTION_1_SENTENCE | 盲人導航 pipeline，本地全離線 |
| COMMIT_SHA | 80bea85 |
| TEST_COUNT | 62 |
| STACK_LIST | YOLOv26s + RapidOCR + Gemma 3 1B + mlx-whisper + macOS say |
| TRIGGER_FLOW | 攝影機 → YOLO/OCR/Depth → 三層 LLM 警示 |
| FILE_LIST | pipeline.py, chat.py, omni_sense_ocr.py, omni_sense_asr.py |
| TARGET_USER_DESCRIPTION | 視障使用者（沒有視覺 feedback 通道） |

## Verdict 對應動作

| Codex 結果 | Planning 動作 |
|---|---|
| 0 P0 / 0 P1 → ship-ready | 直接收尾，寫 release prompt |
| 1-3 P0/P1 → 抓最重的 1-3 條 | 寫 fix prompt 進 _inbox.md |
| 4+ P0 → not_ready | 拆批 fix prompts（每批 ≤3 個 P0） |
| 一堆 P2 | 整理進 docs/REFACTOR_OPPORTUNITIES.md，延後 |
