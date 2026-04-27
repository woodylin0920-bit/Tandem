# Phase A R1: rewrite README + HARNESS_ETHOS for Tandem (model-agnostic, self-use-honest) + create ATTRIBUTION.md

## Goal

Phase 0 機械改名後，README + HARNESS_ETHOS 還是 woody-harness 時代的敘事 + Claude-only 視角，跟剛確認的 model-agnostic 願景對不上。本輪做敘事重構**定調**：README + HARNESS_ETHOS + 新檔 ATTRIBUTION.md。R2（其他文件 TUTORIAL/WORKFLOW/CONTRIBUTING/examples）下一輪做。

## Execution profile

- model: sonnet
- effort: medium（design-heavy 文案，但有明確 anchor 跟 hard rules）
- 3 commits（README / HARNESS_ETHOS / ATTRIBUTION + archive 共 4）

## Phase A 拍板（5 條，全部已定調）

| # | 軸 | 拍板 |
|---|---|---|
| 1 | 拆輪 | C — R1 README + HARNESS_ETHOS / R2 其餘 |
| 2 | 雙騎士隱喻 | **C light** — 名字保留、開頭一句解釋、後面工程術語、不再回頭 |
| 3 | audience 語氣 | **B self-use-honest** — 「我為自己做的，fork 隨意；習慣不接近就別硬套」 |
| 4 | model-agnostic 文案 | **B Claude 為主例 + 明文點 markdown 介面 agnostic** |
| 5 | omni-sense 歷史 | **B 搬 ATTRIBUTION.md** — README 不提，獨立檔保存 |

## Background context

- Tandem 願景：**跨專案 self-improving 任意模型** — AI 副手（任意 model）跟著 user 跨專案累積偏好/規則/錯誤經驗
- 現役 wedge 三條：
  1. plan/execute session split + file-based inbox
  2. cross-vendor quality gate (codex audit)
  3. **cross-project self-improving memory layer**（剛 ship T-1a 兌現）— 這條是新替換上來的，原 wedge #3 「accessibility/safety audit」已在內部下放成 `templates/prompts/SAFETY_AUDIT.md` 的 nice-to-have，不再是招牌
- 主驅動 self-use first，公開順帶
- 受眾：工程師（懂 git/bash/commit discipline）

## Files to edit / create

1. **README.md**（74 行）— rewrite per anchor below
2. **docs/HARNESS_ETHOS.md**（106 行）— rewrite per anchor below
3. **ATTRIBUTION.md**（**新檔**，置 repo root）— omni-sense origin story 搬這裡

## Step-by-step

### Step 1: Pre-flight

```bash
pwd | grep -q "/Tandem$" || { echo "FAIL: not in Tandem"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "FAIL: working tree dirty"; git status --short; exit 1; }
[ -f README.md ] && [ -f docs/HARNESS_ETHOS.md ] || { echo "FAIL: source files missing"; exit 1; }
[ ! -f ATTRIBUTION.md ] || { echo "FAIL: ATTRIBUTION.md already exists — abort"; exit 1; }
echo "PASS: pre-flight"
```

### Step 2: 創建 ATTRIBUTION.md（新檔）

用 Write tool 建 `ATTRIBUTION.md` repo root，內容：

```markdown
# Attribution

## Origin: omni-sense

Tandem was extracted from **omni-sense**, an offline accessibility-focused navigation pipeline I shipped in one week as a solo developer using Claude Code.

That sprint forced the workflow into a working shape: two parallel Claude sessions (one planning, one executing), a file-based handoff (`_inbox.md`), atomic phase commits, codex cross-vendor audits, and pre-ship safety gates. Six P0 issues surfaced via codex audit after Phase 1 was "done" — that incident is why phase-gate exists at all.

Rather than re-invent the workflow on every new project, I pulled the scaffolding out into a reusable framework. That framework is Tandem.

## What carried over

- Plan/execute session split with `_inbox.md` handoff
- Codex cross-vendor audit conventions (`templates/prompts/CODEX_AUDIT.md`)
- Phase-gate ship discipline (tests + SLO + clean push state)
- Real-machine smoke testing (`templates/scripts/smoke.sh`)
- Accessibility / safety audit prompt template (`templates/prompts/SAFETY_AUDIT.md`) — kept available as a nice-to-have for projects that need it; not part of Tandem's core wedge

## What did NOT carry over

- Domain-specific code (audio cues, OCR, navigation logic) — those belonged to omni-sense, not the framework
- omni-sense-specific memory entries — Tandem's memory templates are intentionally generic
- "Accessibility-first" positioning — Tandem's positioning is workflow framework for solo engineers, not accessibility tooling
```

**注意**：
- 不要加 emoji、不要 marketing 語氣
- 「Six P0 issues」這條保留作為 phase-gate 存在的真實 origin，是 ethos credibility 訊號

### Step 3: 重寫 README.md

完全 rewrite（用 Write tool）。目標長度 ~85-100 行（比現有略長，因為要塞 self-use-honest opener + 新 wedge）。

**結構**：

```markdown
# Tandem

[badges 維持原樣 4 個 — 不要改 URL]

> Two terminals, one bike: a planner session writes prompts, an executor session ships them. That's the whole metaphor — past this line, it's just a workflow framework.

A workflow framework I built for myself to ship faster with AI-assisted development. Self-use first, fork-friendly, but **not aimed at general adoption**.

If your habits look like mine — Claude Code (or any model with a markdown-aware prompt loop), two terminal sessions, git-native commits, comfort with bash and `_inbox.md`-style handoffs — this might fit. If not, this is probably the wrong tool. I'm not trying to convince you.

## Who this is for

- Solo engineers who already run AI-assisted dev and want it scaffolded
- Comfort with: git / bash / atomic commits / phase gates
- **Not** for: people looking for an IDE, a code generator, a deploy tool, team collaboration features, or a GUI

## What you get

[沿用現有 12 條 bullet — 但每條開頭名詞保留，內文做兩件事：
 (a) 把所有「Claude / Opus / Sonnet」具體 reference 維持（Claude 是主要範例 — model-agnostic 策略 B），
 (b) 在 plan/execute 那條 + memory 那條補一句「介面是 markdown，可換任何 model」

具體：
- "Plan / Execute session split" 那條，最後加一句「Markdown-based interface — works with Claude Code today, portable to any model that can read text prompts and produce file edits」
- "Memory system" 那條，強調「auto-loaded preferences, workflow rules, project state」
- "Cross-project shared memory" 那條，**升級為招牌 wedge** — 把它從 bullet 列表挪上「Why Tandem」之前單獨一段：

## Why Tandem (over rolling your own)

- **vs. raw Claude Code (or any model)**: gives you the prompt-handoff + memory + phase-gate scaffolding instead of starting blank every session. Interface is markdown, so swap models without rewiring.
- **vs. taskmaster / agent frameworks**: pure bash + markdown, zero deps, one-command bootstrap. Fork-friendly because there's nothing to fork *into* — it's just files.
- **vs. writing your own**: extracted from a real shipped solo project (see [ATTRIBUTION.md](ATTRIBUTION.md)).
- **The招牌 differentiator — cross-project self-improving memory**: your AI's understanding of you (preferences, workflow rules, lessons learned) lives once at `~/.claude-work/_shared/memory/` and follows you into every project. Add a memory once, get it everywhere. The longer you use Tandem, the less you re-explain. See [docs/SHARED_MEMORY.md](docs/SHARED_MEMORY.md).

## Quick start

[沿用現有 quick-start 區塊，但把開頭改成 model-neutral：]

```bash
git clone https://github.com/woodylin0920-bit/Tandem ~/Tandem
cd ~/Desktop/repo
bash ~/Tandem/bootstrap.sh my-new-project
cd my-new-project
```

Open two AI sessions (example uses Claude Code — substitute your model):
```bash
# Terminal 1 (planning):  claude  # Opus, /effort high
# Terminal 2 (executor):  claude --model sonnet  # Sonnet, /effort medium
```

Then `/inbox` in the executor session whenever the planner writes a prompt.

## Maintenance

[沿用現有 Maintenance 區塊，原樣]

## See it in action

[沿用現有「See it in action」區塊，原樣 — examples/hello-cli/]

## Roadmap

[沿用現有 Roadmap 區塊，但更新進度：
- Phase 1 ✅
- Phase 2 ✅
- Phase 4 ✅
- v0.4.1 release ✅
- T-1a ✅ (full — α infra + β promote tool + real promotion of 12 feedback to shared)
- S-1 ✅ (bootstrap upgrade/remove modes)
- Phase 0 ✅ (rename to Tandem)
- **Phase A (in progress)** — narrative refactor for model-agnostic positioning
- Phase B — model + effort recommendation system (was 4e)
- Phase C — learning loop (`/lessons` slash)
- ~~Phase 3: CI / hooks / push notifications~~ deferred
]

## Contributing

[沿用，但語氣調 self-use-honest：]

If you fork and your adaptation generalizes, PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md). I won't promise fast turnaround — this is a self-use tool, contributions get reviewed when I'm working on Tandem itself.

## License

MIT (see LICENSE).
```

**Hard rules for README rewrite**：
- ✅ 保留 4 個 badges 整行不動（URL 不變）
- ✅ 用「Two terminals, one bike」開頭一句解釋名字 — 拍板 #2 light 隱喻：講完就轉工程語言，後面**不再用** rider / cadence / front seat 之類詞
- ✅ Audience 段語氣 self-use-honest，**明寫 "Not for: ..."**
- ✅ Cross-project shared memory 升上招牌 wedge 位置（「Why Tandem」段最後一條 bold「招牌 differentiator」）
- ✅ Model-agnostic 落地：Claude 是 primary example，但開頭、quick-start、Why Tandem 都點出「介面 markdown / works with any model」
- ❌ **不要**：emoji / 「solo founders」/「extracted from omni-sense」/ accessibility 字眼 / marketing 語氣（「supercharge / awesome / amazing / 🚀」之類）/ ✨「2026 the year of...」之類胡扯
- ❌ 「Why Tandem」不要寫「Why Tandem helps you...」這種 helps-language；要直陳對比

### Step 4: 重寫 docs/HARNESS_ETHOS.md

完全 rewrite。目標長度 ~120-140 行（略長因為加新章節）。

**章節順序與要點**：

1. **# Harness ethos**（標題不變）
2. **Opening**：保留「Why Tandem looks the way it does. Read once.」
3. **§1 Bash + markdown only** — 沿用現有，**最後加一段**：
   > And because the entire interface is markdown, the framework isn't bound to one AI vendor. Memory files, inbox prompts, slash commands — all plain text. Tandem ships with Claude Code as the primary example because that's what I use, but porting to a different model is mechanical: read the same files, produce the same outputs.
4. **§2 Atomic commits** — 沿用現有
5. **§3 Phase-gated shipping** — 沿用現有
6. **§4 Plan / execute split** — **改寫**：
   > A planner session writes prompts. An executor session ships them. The two never run in the same terminal.
   >
   > In my setup the planner is Claude Code with Opus and the executor is Claude Code with Sonnet — Sonnet's literalness is a feature, not a limitation. It forces explicit prompts; if the executor misunderstands, the prompt was ambiguous. Fix the prompt, not the model.
   >
   > But the split is the principle, not the model pairing. Any pair where one side is reasoning-stronger (planner) and the other is execution-strong (executor) works — Claude/Codex, Claude/Claude, two human-AI pairs across timezones, etc. The prompt is just markdown.
   >
   > Concretely: planner writes a fully self-contained `_inbox.md` prompt with exact file content, exact commit messages, exact verification commands. Executor reads it and ships without asking questions. No context bleed, no re-deliberation.
   >
   > See `WORKFLOW.md` for the session diagram.
7. **§5 Memory-first context** — **大改**，把 cross-project memory 升上來：
   > Context lives in `~/.claude-work/`, not in chat scrollback. Two layers:
   >
   > - `~/.claude-work/_shared/memory/` — preferences and workflow rules that apply to **every** project. Terse-Mandarin replies, planner/executor split, macOS notification quirks, "don't silently continue on error" — these are about *me*, not about any one project.
   > - `~/.claude-work/projects/<slug>/memory/` — current handoff state, phase progress, project-specific decisions. Lives per-project.
   >
   > Shared layer symlinks into every project's memory dir. Add a feedback memory once, get it everywhere I work. **This is the longest-running win of using Tandem**: every project starts already understanding my conventions. The next blank-slate Claude session is many projects ago, not this morning.
   >
   > See `docs/SHARED_MEMORY.md` for the layer architecture and `docs/MEMORY_SYSTEM.md` for the four memory types.
8. **§6 Boil the lake on P0 before P1** — 沿用現有，但**移除**「accessibility-critical or safety-critical」這條當成 framework 普遍原則的寫法。改用更通用的措辭：「Six P0 issues surfaced via codex audit after Phase 1 was 'done' on a real solo project (see ATTRIBUTION.md). All six were fixed before any Phase 2 code was written. Carrying known P0s across a phase boundary compounds them.」（不要 mention accessibility，那是 omni-sense 特定情境，已經搬 ATTRIBUTION）
9. **§7 Real-machine smoke > CI green** — 沿用現有但**改寫 accessibility 段**：
   - 原文：「For accessibility-critical or safety-critical projects, silent failure is a safety issue, not a test metric. A failing audio cue with no error feedback is a P0 regardless of what pytest says.」
   - 改成：「For projects where silent failure is a real risk (hardware control, side effects on real users, anything where 'green test, broken behavior' has cost), pytest doesn't tell you the truth.」
   - 保留 `templates/scripts/smoke.sh` 介紹 + 「runs once per phase ship, not in CI」
10. **§8 Fork-friendly by default** — 沿用現有
11. **§9 Cross-vendor quality gates**（**新章節**）— 在 §8 後 §10 之前插入：
    > Quality assurance should not depend on a single vendor agreeing with itself.
    >
    > Tandem ships `/codex-audit` as a slash command — at the end of each phase, OpenAI Codex reviews what Claude shipped against a 7-dimension prompt (`templates/prompts/CODEX_AUDIT.md`). The two systems disagree often enough that the audit catches real issues — bias overlap is lower than running two Claude sessions over the same code.
    >
    > Same logic on the input side: any model that can read markdown can be a planner or executor. The framework doesn't require one vendor; it works because the *interface* is text, not because of any specific tool integration.
12. **§10 What this is NOT** — 沿用 §9 現有但改寫：
    > Not an agent framework. Not taskmaster. Not a productivity dashboard.
    >
    > Tandem is workflow scaffolding for **one engineer + their AI of choice**. The "orchestration" is you — picking what to build, deciding tradeoffs, writing prompts the executor session can ship without re-asking. The framework provides the folder structure, the handoff convention, the memory layer, and the phase gate. You provide the judgment.
    >
    > For multi-agent orchestration → langgraph, autogen, similar. For task management → taskmaster. For Claude Code keyboard shortcuts → `/config`. Different tools, different problems.
    >
    > This is for the engineer who wants to move fast with AI assistance without giving up clarity about what is happening and why.

**Hard rules for HARNESS_ETHOS rewrite**：
- ✅ 保留所有 §-numbered structure（讀者熟）但允許重寫每節內容
- ✅ §4 改成「split is the principle, not the model pairing」+ Claude/Sonnet 是主要 example
- ✅ §5 升級為 cross-project memory 招牌敘事
- ✅ §9 新章節 cross-vendor gates 落地第二條 wedge
- ✅ §10 收尾 — 「one engineer + their AI of choice」（不寫死 Claude Code）
- ❌ 移除 §6/§7 的「accessibility-critical / safety-critical」生硬連結（搬 ATTRIBUTION 後 ethos 不該再 mention）
- ❌ 不要加 emoji / marketing 語氣
- 章節 numbering 變 1-10（多了 §9 cross-vendor gates）

### Step 5: 中段 verification

```bash
# 5a. 三個檔都改/建了
[ -f ATTRIBUTION.md ] && echo "PASS: ATTRIBUTION.md created"
git diff --stat README.md docs/HARNESS_ETHOS.md
# 應該都顯示有 substantial 改動

# 5b. README 不再有 omni-sense / accessibility 字眼
! grep -i "omni-sense\|accessibility" README.md && echo "PASS: README clean of omni-sense/accessibility"
! grep -E "extracted from real-world solo project" README.md && echo "PASS: README old origin line removed"

# 5c. README 有 self-use-honest 訊號
grep -q "Not for:" README.md && echo "PASS: README has 'Not for' section"
grep -q "self-use\|self-use first\|not aimed at general adoption\|not trying to convince" README.md && echo "PASS: README has self-use-honest tone"

# 5d. README 有 model-agnostic 點題
grep -qi "any model\|markdown-based\|markdown-aware\|portable to any" README.md && echo "PASS: README has model-agnostic mention"

# 5e. README 有 cross-project memory 招牌段
grep -q "cross-project self-improving memory\|招牌\|differentiator" README.md && echo "PASS: README has cross-project memory wedge"

# 5f. HARNESS_ETHOS 有新 §9 cross-vendor gates
grep -q "Cross-vendor quality gates" docs/HARNESS_ETHOS.md && echo "PASS: HARNESS_ETHOS has cross-vendor section"

# 5g. HARNESS_ETHOS §4 split 改成 principle 不綁 model
grep -A3 "^## 4. Plan" docs/HARNESS_ETHOS.md | grep -q "principle\|any pair\|model pairing" && echo "PASS: HARNESS_ETHOS §4 model-agnostic"

# 5h. HARNESS_ETHOS §6/§7 不再有 accessibility 生硬連結
! grep -E "accessibility-critical|safety-critical" docs/HARNESS_ETHOS.md && echo "PASS: HARNESS_ETHOS §6/§7 cleaned"

# 5i. ATTRIBUTION 有 omni-sense origin
grep -q "omni-sense" ATTRIBUTION.md && echo "PASS: ATTRIBUTION mentions omni-sense"

# 5j. bash syntax 沒被 markdown 改動連帶弄壞
bash -n bootstrap.sh && echo "PASS: bootstrap syntax"

# 5k. test-bootstrap 維持綠
bash scripts/test-bootstrap.sh && echo "PASS: test-bootstrap 32/32" || { echo "FAIL: test-bootstrap"; exit 1; }
```

要全 PASS 才繼續。任一 FAIL → STOP，**不要強跑**，回報哪條沒過、把當前內容貼出來讓 planner 評估要不要再改。

### Step 6: Commit each file separately（atomic）

```bash
# Commit 1: README
git add README.md
git diff --cached --stat
git commit -m "docs: README rewritten for Tandem self-use-honest positioning + model-agnostic framing

- Drop 'extracted from omni-sense' from main narrative (moved to ATTRIBUTION.md)
- Add 'Who this is for / Not for' self-use-honest opening
- Cross-project shared memory layer promoted to招牌 differentiator (wedge #3, replacing accessibility audit)
- Light tandem metaphor (one-line opener), then engineering language
- Model-agnostic phrasing: Claude as primary example, markdown interface portable to any model
- Roadmap updated: T-1a/S-1/Phase 0 shipped, Phase A in progress, Phase B/C queued"

# Commit 2: HARNESS_ETHOS
git add docs/HARNESS_ETHOS.md
git commit -m "docs: HARNESS_ETHOS rewrite for model-agnostic ethos + cross-project memory + cross-vendor gates

- §1: bash+markdown reframed as model-portability foundation
- §4 plan/execute split: principle, not Claude-specific (Sonnet/Opus is example, not requirement)
- §5 memory-first: cross-project shared memory layer becomes the long-game win
- §6/§7: accessibility-critical/safety-critical references removed (those belong to omni-sense, see ATTRIBUTION.md)
- §9 (new) cross-vendor quality gates: codex audit on Claude commits, two-vendor disagreement catches what one-vendor self-review misses
- §10 (renumbered) closing: 'one engineer + their AI of choice'"

# Commit 3: ATTRIBUTION
git add ATTRIBUTION.md
git commit -m "docs: ATTRIBUTION.md — omni-sense origin moved out of main narrative

Tandem's framework was extracted from omni-sense (offline accessibility-focused
navigation pipeline I shipped in 1 week). That sprint forced the workflow into
its current shape — phase-gate exists because of 6 P0s caught by codex audit
after Phase 1 was 'done' on omni-sense.

Origin story preserved here so README + HARNESS_ETHOS can stay focused on the
framework rather than its lineage. Accessibility/safety audit templates remain
available as nice-to-have, not as core wedge."
```

### Step 7: Final verification

```bash
git log -4 --oneline
git status
# working tree should be clean except _inbox.md
```

### Step 8: Archive

```bash
bash scripts/archive-prompts.sh
git push origin main
```

archive 會把本檔歸檔成 `docs/prompts/<date>-phase-a-r1-readme-ethos-attribution.md` 並清空 inbox。

## Hard rules (跨步驟)

1. **絕不**用 emoji（除了 README 既有的 status emoji `✅ ⏳ 🔲 ~~ ❌` 那類 roadmap markers 可以保留）
2. **絕不**marketing 語氣（"supercharge / awesome / 🚀 / unleash / next-gen / blazingly fast"）
3. **絕不**加新檔（除了 ATTRIBUTION.md）
4. 任何 step FAIL → STOP 印錯誤，把當前 README/HARNESS_ETHOS 部分貼出來讓 planner 看，**不強跑**
5. 三個 commit 不要合併（atomic — 各自可 revert）
6. 通知：成功 → `afplay /System/Library/Sounds/Glass.aiff` + osascript notification；失敗 → `say -v Mei-Jia "卡住了"`
7. 不 auto-queue 下一輪（Phase A R2 由 user 拍板後另開 inbox）

## Result block

跑完 append：

```markdown
## Result

**Status**: ✅ shipped | ❌ blocked
**Commits**: 4 (incl. archive)
<sha> docs: README rewritten for Tandem self-use-honest + model-agnostic
<sha> docs: HARNESS_ETHOS rewrite + cross-vendor gates §9
<sha> docs: ATTRIBUTION.md — omni-sense origin moved out
<sha> chore: archive phase-a-r1-readme-ethos-attribution inbox prompt + result

**Verification**:
- README clean of omni-sense/accessibility: PASS / FAIL
- README has 'Not for:' self-use-honest section: PASS / FAIL
- README has model-agnostic mention: PASS / FAIL
- README has cross-project memory wedge: PASS / FAIL
- HARNESS_ETHOS has §9 cross-vendor gates: PASS / FAIL
- HARNESS_ETHOS §4 model-agnostic: PASS / FAIL
- HARNESS_ETHOS §6/§7 cleaned: PASS / FAIL
- ATTRIBUTION mentions omni-sense origin: PASS / FAIL
- bash -n bootstrap: PASS / FAIL
- test-bootstrap.sh 32/32: PASS / FAIL

**Push**: ✅ pushed / ⏸ pending
**Blockers**: none / <description>
```

## Result

**Status**: ✅ shipped
**Commits**: 4 (incl. archive)
93275da docs: README rewritten for Tandem self-use-honest positioning + model-agnostic framing
5419de4 docs: HARNESS_ETHOS rewrite for model-agnostic ethos + cross-project memory + cross-vendor gates
831c1bd docs: ATTRIBUTION.md — omni-sense origin moved out of main narrative
5aa353e chore: archive phase-a-r1-readme-ethos-attribution inbox prompt + result

**Verification**:
- README clean of omni-sense/accessibility: PASS
- README has 'Not for:' self-use-honest section: PASS (line 15, **Not for**:)
- README has model-agnostic mention: PASS
- README has cross-project memory wedge: PASS
- HARNESS_ETHOS has §9 cross-vendor gates: PASS
- HARNESS_ETHOS §4 model-agnostic: PASS
- HARNESS_ETHOS §6/§7 cleaned: PASS
- ATTRIBUTION mentions omni-sense origin: PASS
- bash -n bootstrap: PASS
- test-bootstrap.sh 32/32: PASS

**Push**: ✅ pushed to origin/main
**Blockers**: none
