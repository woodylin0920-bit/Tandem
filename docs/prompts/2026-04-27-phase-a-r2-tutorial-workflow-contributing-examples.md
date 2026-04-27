# Phase A R2: extend R1 framing into TUTORIAL + WORKFLOW + CONTRIBUTING + examples

## Goal

R1 已把 README + HARNESS_ETHOS + ATTRIBUTION 改成 model-agnostic + self-use-honest 定調。R2 把同樣定調**延伸**到剩餘 5 個對外文件：TUTORIAL / WORKFLOW / CONTRIBUTING / examples/hello-cli/README / examples/hello-cli/WALKTHROUGH。

**這輪是 light-touch 不是 rewrite** — 主要做精準 surgical 修改：
- 把寫死 Claude/Opus/Sonnet 的地方改成 model-agnostic（Claude 為主例 + 開頭點 markdown 介面 portable）
- 移除遺留 omni-sense origin 句（「battle-tested on solo project work, 1 week, 4 phases, 6 P0 safety fixes」這類）
- 語氣輕度對齊 R1 self-use-honest，不要全篇重寫

## Execution profile

- model: sonnet
- effort: medium（5 個檔但每個都是 surgical edit，不是 full rewrite）
- 5 commits（每檔一 commit）+ 1 archive = 6 commits

## R1 定調回顧（必須延續）

| 軸 | 拍板 |
|---|---|
| 隱喻 | **light** — 名字保留、開頭一句解釋、後面工程術語、不再回頭 |
| 語氣 | **self-use-honest** — 「我為自己做的」誠實對外，不勸進 |
| Model 文案 | **Claude 為主例 + markdown 介面 agnostic** |
| omni-sense | **移到 ATTRIBUTION.md，主敘事不提** |
| accessibility | **不再當 framework 普遍原則，只當 templates/prompts/SAFETY_AUDIT.md 的 nice-to-have** |

## Files to edit (5 個)

1. `docs/TUTORIAL.md`（298 行，26 Claude/Opus/Sonnet refs）
2. `docs/WORKFLOW.md`（47 行，9 refs，含 ASCII diagram）
3. `CONTRIBUTING.md`（95 行，3 refs）
4. `examples/hello-cli/README.md`（78 行，3 refs）
5. `examples/hello-cli/WALKTHROUGH.md`（131 行，8 refs）

## Step-by-step

### Step 1: Pre-flight

```bash
pwd | grep -q "/Tandem$" || { echo "FAIL: not in Tandem"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "FAIL: working tree dirty"; git status --short; exit 1; }
[ -f docs/TUTORIAL.md ] && [ -f docs/WORKFLOW.md ] && [ -f CONTRIBUTING.md ] && [ -f examples/hello-cli/README.md ] && [ -f examples/hello-cli/WALKTHROUGH.md ] || { echo "FAIL: source files missing"; exit 1; }
echo "PASS: pre-flight"
```

### Step 2: docs/WORKFLOW.md 修改（最先做，最小範圍）

當前 47 行，最關鍵問題：
- L3 origin 句：`battle-tested on solo project work (1 week, 4 phases, 6 P0 safety fixes resolved)` — omni-sense 殘影
- L9-22 ASCII diagram：寫死 「(terminal Opus 4.7)」/「(terminal Sonnet)」
- L23-29 cycle steps：寫死 Opus / Sonnet
- L36-39 rules of thumb：「Sonnet never makes architecture decisions」+ 「Codex audit before any user-facing ship」

**修法**：

(a) L3 改成（用 Edit tool）：
- 原：`This is the day-to-day flow battle-tested on solo project work (1 week, 4 phases, 6 P0 safety fixes resolved).`
- 新：`This is the day-to-day flow Tandem is built around. The split is the principle — the specific model pairing is up to you. See [ATTRIBUTION.md](../ATTRIBUTION.md) for the project where this workflow originally crystallized.`

(b) L9-22 ASCII diagram，把標頭改成 model-neutral，附加一行「in my setup: Opus / Sonnet」說明：

當前：
```
┌─────────────────────────┐         ┌──────────────────────────┐
│  Planning session       │         │  Execution session       │
│  (terminal Opus 4.7)    │         │  (terminal Sonnet)       │
```

改成：
```
┌─────────────────────────┐         ┌──────────────────────────┐
│  Planning session       │         │  Execution session       │
│  (reasoning-strong)     │         │  (execution-strong)      │
```

並在 diagram 下方加一段（在 `## Cycle per phase` 之前）：
```markdown
> In my setup the planning side is Claude Code with Opus and the executor is Claude Code with Sonnet. Any pair where one model reasons well and the other ships well works — Claude/Codex, Claude/Claude, two-vendor combos. The interface between them is just markdown.
```

(c) L23-29 cycle steps：把「Opus 寫」改成「planner writes」，「Sonnet 跑」改成「executor runs」。具體：

- `1. **Plan** in Opus session:` → `1. **Plan** in the planning session:`
- `2. **Write prompt**: Opus writes to docs/prompts/_inbox.md` → `2. **Write prompt**: planner writes to docs/prompts/_inbox.md`
- `3. **Execute** in Sonnet session: type /inbox` → `3. **Execute** in the executor session: type /inbox`
- `4. **Report**: Sonnet pushes commits` → `4. **Report**: executor pushes commits`
- `5. **Interpret**: paste report back to Opus` → `5. **Interpret**: paste report back to the planner`

(d) L36-39 rules of thumb：
- `Sonnet **never makes architecture decisions** — those happen in Opus session` → `The executor session **never makes architecture decisions** — those happen in the planner session.`
- 「Pytest is always green」改成「Tests are always green」（pytest 寫死特定語言，不通用）
- `Codex audit before any user-facing ship (not in Phase 1, see Phase 2)` 維持原樣（codex audit 是具體 wedge，不抽象化）

### Step 3: CONTRIBUTING.md 修改（最簡單，只 3 refs）

當前 L5: `solo Claude Code users building AI-augmented projects` — 改成 `solo engineers using AI-assisted dev tooling`

當前 L18: `Expanding scope beyond "one person + Claude Code"` — 改成 `Expanding scope beyond "one engineer + their AI of choice"`

剩下其他 Claude refs 是具體 example 場景（PR 合理性檢查），可保留。

順手檢查整檔語氣是否跟 R1 README 一致 — CONTRIBUTING.md 開頭已經是 self-use-honest 風格（「This is a personal framework」），不需大動。

### Step 4: docs/TUTORIAL.md 修改（最大量，但仍 surgical）

26 refs 大多是具體操作指引（要跑哪條 `claude` 指令、`/effort` 設多少），這些**保留** — 因為 TUTORIAL 是 walk-through，要具體可抄。

**只改三類**：

(a) **Prerequisites 段**：在 `claude` CLI 那條後加一行說明：
- 原：`**`claude` CLI** — install via npm install -g @anthropic-ai/claude-code (or the Anthropic docs). Confirm: claude --version`
- 加一行（在這行後）：
  > Tandem's instructions use Claude Code as the concrete example throughout this tutorial. The framework itself is markdown-based and works with any model that can read prompts and produce file edits — but the worked walkthrough below assumes Claude Code so commands are copy-pasteable.

(b) **第一次提到「open two sessions」的地方**：補一句 model-agnostic 提醒。grep 找 `Opus session` 或 `Sonnet session` 第一次出現，加一個 callout box。例如：

```markdown
> **On the model pairing**: this tutorial uses Opus (planner) + Sonnet (executor) because that's what works for me. Any reasoning-strong/execution-strong pair works. If your preferred pairing is different, swap accordingly — only the model name changes, not the workflow.
```

(c) **任何 "battle-tested" / "real-world" 字眼帶 omni-sense 殘影的**：grep `battle-tested\|real-world\|6 P0\|safety` 在 TUTORIAL.md，把 omni-sense 暗示去除（這檔本身可能沒有，verify only）。

**不要**：把 26 處 `claude --model sonnet` 全改通用 — 那是具體操作指引，改了就不能 copy-paste，違背 TUTORIAL 目的。

### Step 5: examples/hello-cli/README.md + WALKTHROUGH.md 修改

example 本身是 Claude Code 跑出來的真實 snapshot，不需要 model-agnostic 化（snapshot = historical artifact）。

**只改一處**：兩檔開頭各加一句 callout：

`examples/hello-cli/README.md` 開頭附近加：
```markdown
> This snapshot was produced with Claude Code (Opus + Sonnet) — concrete artifact, not a generalized example. The workflow itself is model-agnostic; the choice of Claude here just reflects what was actually used to ship.
```

`examples/hello-cli/WALKTHROUGH.md` 開頭附近同樣加：
```markdown
> Walkthrough is real session output from Claude Code. The narrative still applies regardless of model — substitute whatever planner/executor pairing you use.
```

剩下內容不動（example 是「給看 workflow 在實際 commit 上長什麼樣」，把 Claude 名字拿掉反而變抽象）。

### Step 6: 中段 verification

```bash
# 6a. 五個檔都有改動
git diff --stat docs/TUTORIAL.md docs/WORKFLOW.md CONTRIBUTING.md examples/hello-cli/README.md examples/hello-cli/WALKTHROUGH.md
# 全部都應該顯示有 M 改動

# 6b. WORKFLOW 移除 omni-sense 殘影
! grep -E "battle-tested on solo project work|6 P0 safety fixes" docs/WORKFLOW.md && echo "PASS: WORKFLOW omni-sense residue removed"

# 6c. WORKFLOW diagram 改成 model-neutral
grep -q "reasoning-strong" docs/WORKFLOW.md && echo "PASS: WORKFLOW diagram model-neutral"
grep -q "In my setup the planning side is Claude Code" docs/WORKFLOW.md && echo "PASS: WORKFLOW has Claude-as-example callout"

# 6d. WORKFLOW cycle steps generalised
grep -q "in the planning session\|planner writes\|in the executor session\|executor pushes" docs/WORKFLOW.md && echo "PASS: WORKFLOW cycle generalised"

# 6e. CONTRIBUTING 改用 model-agnostic 措辭
grep -q "one engineer + their AI of choice" CONTRIBUTING.md && echo "PASS: CONTRIBUTING agnostic"
! grep -q "one person + Claude Code" CONTRIBUTING.md && echo "PASS: CONTRIBUTING old phrase removed"

# 6f. TUTORIAL 加了 model-agnostic callout
grep -q "any model that can read prompts and produce file edits\|markdown-based and works with any model" docs/TUTORIAL.md && echo "PASS: TUTORIAL has agnostic callout"
grep -q "On the model pairing\|Any reasoning-strong/execution-strong pair" docs/TUTORIAL.md && echo "PASS: TUTORIAL has pairing callout"

# 6g. examples 加了 snapshot disclaimer
grep -q "model-agnostic\|substitute whatever planner/executor" examples/hello-cli/README.md examples/hello-cli/WALKTHROUGH.md && echo "PASS: examples snapshot disclaimer"

# 6h. bash syntax + test-bootstrap
bash -n bootstrap.sh && echo "PASS: bootstrap syntax"
bash scripts/test-bootstrap.sh && echo "PASS: test-bootstrap 32/32" || { echo "FAIL: test-bootstrap"; exit 1; }
```

要全 PASS 才繼續。任一 FAIL → STOP，貼當前內容讓 planner 看，**不強跑**。

### Step 7: Commit each file separately（atomic）

```bash
# Commit 1: WORKFLOW
git add docs/WORKFLOW.md
git commit -m "docs: WORKFLOW.md model-neutral diagram + planner/executor terminology

- ASCII diagram now shows 'reasoning-strong' / 'execution-strong' instead of Opus/Sonnet hardcoded
- Add Claude-as-example callout under diagram (any pair works, framework is markdown)
- Cycle steps switch from 'Opus session'/'Sonnet session' to 'planner session'/'executor session'
- Drop omni-sense origin sentence ('1 week, 4 phases, 6 P0 safety fixes') — origin in ATTRIBUTION.md
- 'Pytest always green' → 'Tests always green' (language-neutral)"

# Commit 2: CONTRIBUTING
git add CONTRIBUTING.md
git commit -m "docs: CONTRIBUTING.md positioning matches Phase A R1 framing

- 'solo Claude Code users' → 'solo engineers using AI-assisted dev tooling'
- 'one person + Claude Code' → 'one engineer + their AI of choice'"

# Commit 3: TUTORIAL
git add docs/TUTORIAL.md
git commit -m "docs: TUTORIAL.md adds model-agnostic callouts

- Prerequisites note: tutorial uses Claude Code for copy-pasteable concreteness, framework itself is model-agnostic markdown
- 'On the model pairing' callout at first two-session mention
- Concrete claude/sonnet command lines preserved (this is a walkthrough, not a reference)"

# Commit 4: examples/hello-cli/README
git add examples/hello-cli/README.md
git commit -m "docs: hello-cli README — Claude Code snapshot disclaimer"

# Commit 5: examples/hello-cli/WALKTHROUGH
git add examples/hello-cli/WALKTHROUGH.md
git commit -m "docs: hello-cli WALKTHROUGH — model-agnostic narrative note"
```

### Step 8: Final verification + Archive

```bash
git log -6 --oneline
git status

bash scripts/archive-prompts.sh
git push origin main
```

archive 會把本檔歸檔成 `docs/prompts/<date>-phase-a-r2-tutorial-workflow-contributing-examples.md` 並清空 inbox。

## Hard rules

1. **Surgical edits 不是 rewrite** — 5 檔總改動行數應該 < 100 行（不含新增 callout）
2. TUTORIAL 的具體 `claude` / `claude --model sonnet` 操作指令**不要全替換成通用** — 那是 walkthrough 賣點
3. examples/hello-cli/* 不重寫內容（它是 historical snapshot），只加開頭 disclaimer
4. **絕不**用 emoji / marketing 語氣 / 修辭過度的 self-use-honest（避免變成「我做的工具好爛你別用」這種反向過度）
5. 任何 step FAIL → STOP 印錯誤、貼當前檔內容、**不強跑**
6. 5 個 commit 不合併（atomic）
7. 通知：成功 → `afplay /System/Library/Sounds/Glass.aiff` + osascript notification；失敗 → `say -v Mei-Jia "卡住了"`
8. **本輪 ship 完 STOP** — Phase A 完整收尾，Phase B / C 等 user 拍板。**不 auto-queue**

## Result block

跑完 append：

```markdown
## Result

**Status**: ✅ shipped | ❌ blocked
**Commits**: 6 (incl. archive)
<sha> docs: WORKFLOW.md model-neutral diagram
<sha> docs: CONTRIBUTING.md positioning matches R1
<sha> docs: TUTORIAL.md adds model-agnostic callouts
<sha> docs: hello-cli README — snapshot disclaimer
<sha> docs: hello-cli WALKTHROUGH — model-agnostic narrative note
<sha> chore: archive phase-a-r2-tutorial-workflow-contributing-examples inbox prompt + result

**Verification**:
- WORKFLOW omni-sense residue removed: PASS / FAIL
- WORKFLOW diagram model-neutral: PASS / FAIL
- WORKFLOW cycle steps generalised: PASS / FAIL
- CONTRIBUTING agnostic phrasing: PASS / FAIL
- TUTORIAL has agnostic callouts: PASS / FAIL
- TUTORIAL preserves concrete claude commands: PASS / FAIL
- examples have snapshot disclaimer: PASS / FAIL
- bash -n bootstrap: PASS / FAIL
- test-bootstrap.sh 32/32: PASS / FAIL

**Push**: ✅ pushed / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ✅ shipped
**Commits**: 6 (incl. archive)
bd6deb3 docs: WORKFLOW.md model-neutral diagram + planner/executor terminology
ea2fc5a docs: CONTRIBUTING.md positioning matches Phase A R1 framing
3588e30 docs: TUTORIAL.md adds model-agnostic callouts
ce2563a docs: hello-cli README — Claude Code snapshot disclaimer
ff875a4 docs: hello-cli WALKTHROUGH — model-agnostic narrative note
(archive commit) chore: archive phase-a-r2-tutorial-workflow-contributing-examples inbox prompt + result

**Verification**:
- WORKFLOW omni-sense residue removed: PASS
- WORKFLOW diagram model-neutral: PASS
- WORKFLOW cycle steps generalised: PASS
- CONTRIBUTING agnostic phrasing: PASS
- TUTORIAL has agnostic callouts: PASS
- TUTORIAL preserves concrete claude commands: PASS
- examples have snapshot disclaimer: PASS
- bash -n bootstrap: PASS
- test-bootstrap.sh 32/32: PASS

**Push**: ✅ pushed to origin/main
**Blockers**: none
