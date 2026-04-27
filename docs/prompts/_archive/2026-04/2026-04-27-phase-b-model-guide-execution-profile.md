# Phase B: MODEL_GUIDE.md + Execution profile soft convention

## Goal

把 model + effort 推薦從「planner 腦袋」公開成 `docs/MODEL_GUIDE.md` 啟發式表（fork-friendly + 自己未來忘記時可查），並把 de facto 已存在的 Execution profile convention 寫進 templates / docs，讓新 forker 自然採用。

## Execution profile

- model: sonnet
- effort: medium（MODEL_GUIDE.md 內容已 inline 提供，但 templates/CLAUDE.md + docs 各處要小心對齊）
- 3 commits + archive = 4

## Phase B 拍板（5 條，全部已定調）

| # | 軸 | 拍板 |
|---|---|---|
| 1 | scope | **C** — MODEL_GUIDE.md + Execution profile 軟性 convention（不做 `/recommend` slash） |
| 2 | model 範圍 | **B** — Claude 主表 + 原則延伸到其他 model |
| 3 | heuristic 來源 | **B** — 自己 archive 經驗歸納（21 個 archived rounds 為基底） |
| 4 | `/recommend` | skip |
| 5 | convention 強制度 | **C** — `templates/prompts/_inbox.md` 註解 + `docs/REFERENCE.md` 一句 |

## Background context

- 現役 wedge 三條：plan/execute split + cross-vendor gates + cross-project memory layer
- Phase A 已把對外敘事改成 model-agnostic
- 但 `templates/CLAUDE.md` 還寫死「Planning session (terminal **Opus 4.7**) / Execution session (**Sonnet**)」— 是 Phase A 的漏網之魚，本輪順手修
- 21 個 archived inbox rounds 是 heuristic 真實基底（self-use-honest 寫法：「我跑出這個 pattern」不是「官方建議」）

## Files to create / edit (5 個 surface, 3 commits)

1. **docs/MODEL_GUIDE.md**（新檔）
2. **templates/prompts/_inbox.md** — 加 Execution profile reminder 註解
3. **templates/CLAUDE.md** — Workflow 段改 model-agnostic（Phase A 漏網）
4. **docs/REFERENCE.md** — 加 Execution profile convention 列 + MODEL_GUIDE 連結
5. **docs/WORKFLOW.md** — 補一句 Execution profile 說明

## Step-by-step

### Step 1: Pre-flight

```bash
pwd | grep -q "/Tandem$" || { echo "FAIL: not in Tandem"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "FAIL: working tree dirty"; git status --short; exit 1; }
[ -f docs/REFERENCE.md ] && [ -f docs/WORKFLOW.md ] && [ -f templates/CLAUDE.md ] && [ -f templates/prompts/_inbox.md ] || { echo "FAIL: source files missing"; exit 1; }
[ ! -f docs/MODEL_GUIDE.md ] || { echo "FAIL: MODEL_GUIDE.md already exists — abort"; exit 1; }
echo "PASS: pre-flight"
```

### Step 2: 創建 docs/MODEL_GUIDE.md（新檔）

用 Write tool 建 `docs/MODEL_GUIDE.md`，內容如下（inline 全文，**直接照貼**，不要 paraphrase）：

```markdown
# Model Guide — picking model + effort for inbox rounds

How I pick which model + `/effort` setting goes into `## Execution profile` for each inbox round. Empirical, not theoretical — these patterns came from running 20+ inbox rounds in Tandem and earlier solo projects.

## TL;DR — default split

- **Planner session**: Claude Code with Opus, `/effort high` (bump to `xhigh` for architecture)
- **Executor session**: Claude Code with Sonnet, `/effort medium` (drop to `low` for trivial work)

This is what I run. Deviate when the task type matches one of the rows below.

## Heuristic table

| Task type | Model | Effort | Why |
|---|---|---|---|
| Strategy / phase design / tradeoff calls | Opus | high (xhigh for architecture) | Bad decisions propagate through future commits |
| Authoring inbox prompts | Opus | high | Prompt clarity == executor output quality |
| Mechanical rename / sed across repo | Sonnet | low | No reasoning, pure substitution; literalness is the asset |
| Single-file fix, < 50 lines, clear scope | Sonnet | low | Bounded edits — Sonnet's literalness shines |
| Multi-file refactor, design-light | Sonnet | medium | Several files but each well-defined |
| Multi-file refactor, design-heavy WITH explicit anchors | Sonnet | medium | Complex, but planner pre-decided structure → executor doesn't redesign |
| New feature: script + docs + tests | Sonnet | medium | Three surfaces, each well-bounded |
| Release cut: CHANGELOG + tag + GH release | Sonnet | medium | Multi-step with side-effects, mechanical once spec'd |
| Retro / dogfood write-up | Sonnet | medium | Read existing artifacts + categorize |
| Bootstrap / lifecycle test (`scripts/test-bootstrap.sh`) | Sonnet | low | Pure verification |

## /effort calibration (Claude Code specific)

- `/effort low` — single decision, no chain-of-thought needed (sed, simple commits, verifiers)
- `/effort medium` — default executor; multi-step with clear anchors
- `/effort high` — default planner; needs reasoning, recovers from ambiguous mid-stream signals
- `/effort xhigh` — architecture decisions, novel design problems with no precedent in this repo

## Other models — principle extension

Tandem's interface is markdown. The model selection principle generalizes:

- **Reasoning-strong → planner role.** Claude Opus, OpenAI o-series, GPT-5 thinking, Gemini Pro thinking. Optimize for tradeoff analysis, not throughput.
- **Execution-strong → executor role.** Claude Sonnet, GPT-5 Codex, Gemini Flash. Optimize for speed + literalness. Literalness is a feature — it forces the planner to be explicit. If the executor misunderstands, the prompt was ambiguous.
- **Avoid for executor**: very small models. Literalness erodes; ambiguous prompts get re-interpreted creatively, which is the opposite of what you want.
- **`/effort` equivalents**: most non-Claude models don't expose an `/effort` knob. Substitute reasoning effort / temperature / thinking-budget settings if available, otherwise accept default.

Pair selection is the principle. The specific model names are the implementation. Swap models without changing the workflow.

## Execution profile convention

Every inbox prompt should declare its profile near the top:

\`\`\`markdown
## Execution profile

- model: sonnet
- effort: medium
- 3 commits + archive
\`\`\`

The planner picks based on this guide. The executor reads the profile as confirmation of what was intended.

This is a soft convention — no lint, no hook. Bootstrapped projects get a comment block in `templates/prompts/_inbox.md` reminding to add it. See [docs/REFERENCE.md](REFERENCE.md) for the convention row.

## Why empirical, not theoretical

Anthropic's official model selection guidance is generic and version-shifting. Tandem's recommendations come from actually shipping inbox rounds and observing which combinations did and didn't work. When a recommendation is wrong, an inbox round will fail — and that's the signal to update this file.

If you fork Tandem and your task profile differs (different domains, different models), edit your fork's `MODEL_GUIDE.md`. The point is the table reflects *your* workflow, not mine.
```

**注意**：上面 markdown 含一個 nested code block（` ```markdown ... ``` `）。寫進去時保持原樣（用 Write tool 整檔寫入即可）。

### Step 3: templates/prompts/_inbox.md — 加 Execution profile reminder

當前該檔幾乎是空的（1-2 newline）。改成：

```markdown
<!--
Inbox prompts in Tandem follow a convention — add this near the top:

## Execution profile

- model: sonnet
- effort: medium
- N commits + archive

The planner picks model/effort based on docs/MODEL_GUIDE.md heuristics.
The executor reads the profile as confirmation. Not enforced (no lint), just the rhythm we use.

Delete this comment when writing your prompt. The rest of the inbox prompt structure is up to you.
-->
```

### Step 4: templates/CLAUDE.md — 改 model-agnostic（Phase A 漏網）

當前 L13-14：
```
- **Planning session (terminal Opus 4.7)**: strategy, decisions, prompt authoring. Writes prompts to `docs/prompts/_inbox.md`.
- **Execution session (Sonnet via `/inbox`)**: commits, pytest, push. Reads `_inbox.md` and executes literally.
```

改成：
```
- **Planning session**: strategy, decisions, prompt authoring. Writes prompts to `docs/prompts/_inbox.md`. (My setup: Claude Code with Opus, /effort high. Any reasoning-strong model works — see docs/MODEL_GUIDE.md.)
- **Execution session (via `/inbox`)**: commits, tests, push. Reads `_inbox.md` and executes literally. (My setup: Claude Code with Sonnet, /effort medium. Any execution-strong model works.)
```

L17 也需要小改：
- 原：`After execution, the prompt is archived to docs/prompts/<descriptive-name>.md.`
- 維持（不改）

### Step 5: docs/REFERENCE.md — 加 Execution profile + MODEL_GUIDE 列

讀 docs/REFERENCE.md 找 docs / commands 的 reference 表（grep 找 `MEMORY_SYSTEM\|HARNESS_ETHOS\|TUTORIAL` 看格式），在 docs reference 那段最後加一列：

```markdown
| `docs/MODEL_GUIDE.md` | Heuristic table for picking model + /effort per inbox round, with `## Execution profile` convention. |
```

如果 REFERENCE.md 有「Conventions」章節，在那加一段：

```markdown
### Execution profile convention

Every inbox prompt declares model + effort + commits near the top in a `## Execution profile` block. Soft convention (no lint), reminded via comment in `templates/prompts/_inbox.md`. See `docs/MODEL_GUIDE.md`.
```

如果沒有 Conventions 章節，找個合適位置加（例如 docs reference 表後）。

### Step 6: docs/WORKFLOW.md — 補一句 Execution profile

讀 WORKFLOW.md，找「## Cycle per phase」step 2「Write prompt」那段（grep 找 "Write prompt"）。當前 sub-bullets 是「PRE-FLIGHT block / boilerplate / atomic commits / verification / reporting template」。在最上面加一條：

```
- `## Execution profile` block (model + effort + commits estimate) — see `docs/MODEL_GUIDE.md`
```

不要改其他地方。

### Step 7: 中段 verification

```bash
# 7a. MODEL_GUIDE 創建
[ -f docs/MODEL_GUIDE.md ] && echo "PASS: MODEL_GUIDE.md created"
grep -q "Heuristic table" docs/MODEL_GUIDE.md && echo "PASS: MODEL_GUIDE has heuristic table"
grep -q "Other models — principle extension" docs/MODEL_GUIDE.md && echo "PASS: MODEL_GUIDE has agnostic extension"
grep -q "Execution profile convention" docs/MODEL_GUIDE.md && echo "PASS: MODEL_GUIDE has convention section"
grep -q "Why empirical, not theoretical" docs/MODEL_GUIDE.md && echo "PASS: MODEL_GUIDE has empirical justification"

# 7b. templates/prompts/_inbox.md
grep -q "Inbox prompts in Tandem follow a convention" templates/prompts/_inbox.md && echo "PASS: inbox template has reminder"
grep -q "## Execution profile" templates/prompts/_inbox.md && echo "PASS: inbox template shows profile shape"

# 7c. templates/CLAUDE.md model-agnostic
! grep -q "terminal Opus 4.7" templates/CLAUDE.md && echo "PASS: templates/CLAUDE.md no Opus 4.7 hardcode"
grep -q "Any reasoning-strong model works\|MODEL_GUIDE.md" templates/CLAUDE.md && echo "PASS: templates/CLAUDE.md model-agnostic"

# 7d. REFERENCE.md
grep -q "MODEL_GUIDE" docs/REFERENCE.md && echo "PASS: REFERENCE links MODEL_GUIDE"
grep -q "Execution profile" docs/REFERENCE.md && echo "PASS: REFERENCE notes convention"

# 7e. WORKFLOW.md
grep -q "Execution profile.*model + effort" docs/WORKFLOW.md && echo "PASS: WORKFLOW mentions Execution profile"

# 7f. test-bootstrap 維持綠（templates/CLAUDE.md 改了會經 bootstrap 路徑）
bash scripts/test-bootstrap.sh && echo "PASS: test-bootstrap 32/32" || { echo "FAIL: test-bootstrap"; exit 1; }

# 7g. bash syntax
bash -n bootstrap.sh && echo "PASS: bootstrap syntax"
```

要全 PASS 才繼續。

### Step 8: Commits（atomic）

```bash
# Commit 1: MODEL_GUIDE
git add docs/MODEL_GUIDE.md
git commit -m "docs: MODEL_GUIDE.md — heuristic table for model + /effort selection

Empirical recommendations distilled from 20+ archived inbox rounds in
Tandem itself plus earlier solo project work. Claude as primary worked
example (matches Phase A model-agnostic + Claude-as-primary positioning),
with a principle-extension section for other planner/executor model pairs.

Companion: ## Execution profile convention now documented as part of
the inbox prompt format. Soft convention (no lint), see templates/prompts/
_inbox.md reminder + docs/REFERENCE.md row."

# Commit 2: templates polish
git add templates/prompts/_inbox.md templates/CLAUDE.md
git commit -m "chore: bootstrapped projects surface Execution profile convention + model-agnostic workflow

- templates/prompts/_inbox.md: comment block reminds new projects to declare
  ## Execution profile (model + effort + commits) at the top of each prompt
- templates/CLAUDE.md: Workflow section no longer hardcodes Opus 4.7 / Sonnet —
  describes the role (reasoning-strong planner / execution-strong executor)
  and links docs/MODEL_GUIDE.md (Phase A leftover, caught now)"

# Commit 3: docs cross-link
git add docs/REFERENCE.md docs/WORKFLOW.md
git commit -m "docs: REFERENCE + WORKFLOW link MODEL_GUIDE + note Execution profile convention

- REFERENCE.md: new row for docs/MODEL_GUIDE.md + section noting the Execution
  profile soft convention
- WORKFLOW.md: 'Cycle per phase' step 2 (Write prompt) now lists Execution
  profile as the first sub-bullet"
```

### Step 9: Archive

```bash
bash scripts/archive-prompts.sh
git push origin main
```

archive 會把本檔歸檔成 `docs/prompts/<date>-phase-b-model-guide-execution-profile.md` 並清空 inbox。

## Hard rules

1. MODEL_GUIDE.md 內容**直接 inline**（step 2 已給全文），不要自己重寫表格內容（避免發明 task type / 改 effort 等級）
2. templates/CLAUDE.md L13-14 改寫照 step 4 給的版本
3. docs/REFERENCE.md 修改要先讀整檔對齊現有格式（不要破壞表格 alignment）
4. 任何 step FAIL → STOP 印錯誤、不強跑
5. 3 個 commit 不合併（atomic）
6. 通知：成功 → `afplay /System/Library/Sounds/Glass.aiff` + osascript notification；失敗 → `say -v Mei-Jia "卡住了"`
7. **本輪 ship 完 STOP** — 下一步 Phase C 設計討論，**不 auto-queue**

## Result block

跑完 append：

```markdown
## Result

**Status**: ✅ shipped | ❌ blocked
**Commits**: 4 (incl. archive)
<sha> docs: MODEL_GUIDE.md — heuristic table
<sha> chore: bootstrapped projects surface Execution profile convention + model-agnostic workflow
<sha> docs: REFERENCE + WORKFLOW link MODEL_GUIDE
<sha> chore: archive phase-b-model-guide-execution-profile inbox prompt + result

**Verification**:
- MODEL_GUIDE.md created with heuristic table: PASS / FAIL
- MODEL_GUIDE.md has principle-extension section: PASS / FAIL
- MODEL_GUIDE.md has Execution profile convention section: PASS / FAIL
- templates/prompts/_inbox.md has reminder: PASS / FAIL
- templates/CLAUDE.md model-agnostic: PASS / FAIL
- REFERENCE.md links MODEL_GUIDE + notes convention: PASS / FAIL
- WORKFLOW.md mentions Execution profile in cycle: PASS / FAIL
- test-bootstrap.sh 32/32: PASS / FAIL

**Push**: ✅ pushed / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ✅ shipped
**Commits**: 4 (incl. archive)
2c58b6b docs: MODEL_GUIDE.md — heuristic table for model + /effort selection
185e43f chore: bootstrapped projects surface Execution profile convention + model-agnostic workflow
d815900 docs: REFERENCE + WORKFLOW link MODEL_GUIDE + note Execution profile convention
<archive-sha> chore: archive phase-b-model-guide-execution-profile inbox prompt + result

**Verification**:
- MODEL_GUIDE.md created with heuristic table: PASS
- MODEL_GUIDE.md has principle-extension section: PASS
- MODEL_GUIDE.md has Execution profile convention section: PASS
- templates/prompts/_inbox.md has reminder: PASS
- templates/CLAUDE.md model-agnostic: PASS
- REFERENCE.md links MODEL_GUIDE + notes convention: PASS
- WORKFLOW.md mentions Execution profile in cycle: PASS
- test-bootstrap.sh 32/32: PASS (statusline.sh updated to strip HTML comments — comment-only inbox = empty)

**Push**: ✅ pushed
**Blockers**: none
