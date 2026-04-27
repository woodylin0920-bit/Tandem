# Queue task: Phase 4e — model + /effort 推薦系統

## Execution profile
- model: sonnet
- effort: medium-high
- why: 中等範圍新功能（3 commits）；planner 寫 prompt 時不再每次想用哪個模型/effort

---

## 背景

目前 planner 寫 inbox/queue prompt 都半自願在開頭寫 `## Execution profile` block（model + effort + why）。但缺：
- 沒有正式的啟發式指引（什麼任務該用哪個 model）
- 沒有自動化 — planner 每次手算
- 沒強制 — 有時忘了寫

Phase 4e 把這件事系統化。

---

## 任務（3 commits）

### Commit 1 — `docs/MODEL_GUIDE.md` 啟發式表

建立新檔 `docs/MODEL_GUIDE.md`，內容：

1. **可用模型一覽**（從 user memory + 觀察推導）：
   - Opus 4.7（1M context）— 規劃、設計、長 context、決策
   - Sonnet 4.6 — 執行、coding、verification、文檔
   - Haiku 4.5 — 簡單分類、快速 lookup
2. **任務類型 → 推薦**表格：
   | 任務類型 | model | effort | 理由 |
   |---|---|---|---|
   | 多檔架構設計 | opus | high | 需要長 context + 抽象推理 |
   | 實作 + verify | sonnet | medium | 工具呼叫密集、規格明確 |
   | 單檔小修 | sonnet | low | 快速、低成本 |
   | docs polish | sonnet | low | 文字工作 |
   | 大型 refactor 規劃 | opus | high | 跨檔依賴 |
   | bug fix（已定位） | sonnet | medium | 規格清楚 |
   | bug fix（未定位） | opus | high | 需 root cause 推理 |
   | review/audit | opus | medium | 判斷力 |
3. **effort 級別定義**：low / medium / high / max（如 Claude Code 支援）
4. **何時破例**：context 很長 → Opus；commit 數 ≤ 1 → Sonnet low；卡關第二輪 → 升一級

commit: `docs: MODEL_GUIDE.md heuristics for model + effort selection`

### Commit 2 — `.claude/commands/recommend.md` slash command

新 slash `/recommend`，吃使用者輸入的任務描述，吐：
```
model: <opus|sonnet|haiku>
effort: <low|medium|high|max>
why: <1-2 句理由，引用 MODEL_GUIDE 表格哪一列>
```

Slash command instructions：
1. Read `docs/MODEL_GUIDE.md`（必讀，作為依據）
2. 對照 user 描述判斷最接近哪一行
3. 若多列接近 → 取較保守選項（model 高 + effort 中）
4. 輸出格式嚴格（可被 copy-paste 進 prompt 開頭的 `## Execution profile` block）

複製進 bootstrap.sh `.claude/commands/` 區塊。

commit: `feat: /recommend slash command for model + effort selection`

### Commit 3 — Convention 寫入 docs + bootstrap

1. 修改 `docs/REFERENCE.md`：commands 表格加 `/recommend`，新增章節「Execution profile convention」說明 planner 寫 prompt 必須含此 block
2. 修改 `templates/prompts/_inbox.md`（範本）開頭加 `## Execution profile` block 範例 placeholder
3. 修改 `docs/TUTORIAL.md` 對應章節提及 `/recommend`
4. `RESUME.md` 加一行 `/recommend` 介紹

commit: `docs: REFERENCE + TUTORIAL + RESUME document /recommend + Execution profile convention`

---

## 收尾

1. `git mv` 此檔進 `_archive/2026-04/`
2. archived 檔尾 append `## Result`：
   - **Status**: ✅ shipped / ❌ blocked
   - **Verification**:
     - MODEL_GUIDE.md 存在 + 表格完整
     - /recommend slash 語法正確 + bootstrap 複製
     - test-bootstrap PASS
     - 範例 dry-run：丟「修一個小 bug 在 archive-prompts.sh」進 /recommend，看是否吐出合理輸出
   - **Commits**: 3 hashes
3. 通知 fail-only

---

## 驗證 checklist

- [ ] `docs/MODEL_GUIDE.md` 存在
- [ ] `/recommend` slash 可被 Claude Code 識別（在 commands 列表）
- [ ] bootstrap.sh 複製新檔
- [ ] test-bootstrap PASS
- [ ] commits push

## Result

**Status**: ✅ shipped
**Commits**: 3
16f8446 docs: REFERENCE + TUTORIAL + RESUME document /recommend + Execution profile convention
7d7e538 feat: /recommend slash command for model + effort selection
(docs/MODEL_GUIDE.md already existed — Commit 1 was no-op, merged into docs commit)

**Verification**:
- docs/MODEL_GUIDE.md: exists + heuristic table complete ✅
- /recommend slash: .claude/commands/recommend.md created, bootstrap FRAMEWORK_FILES updated ✅
- test-bootstrap: PASS 40/40 ✅
- dry-run /recommend: command reads MODEL_GUIDE, outputs profile block ✅
**Push**: ✅ pushed to origin/main
**Blockers**: none
