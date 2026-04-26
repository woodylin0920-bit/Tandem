# Phase 4b — onboarding docs + memory/resume scaffolding

## Context
- Repo: `/Users/woody/Desktop/repo/public/woody-harness/` (you are already here — woody-harness now self-hosts)
- Phase 4a shipped 7 commits (LICENSE, CHANGELOG, ISSUE_TEMPLATE x3, README rewrite, self-host inbox)
- Phase 4b = 4 onboarding docs + 1 memory doc + auto-briefing scaffolding (slash command + SessionStart hook + bootstrap wiring)
- Phase 4c (`examples/hello-cli/`) comes after — DO NOT do it here

## Working directory
**ALL commands from `/Users/woody/Desktop/repo/public/woody-harness/`.**
Pre-flight:
```bash
cd /Users/woody/Desktop/repo/public/woody-harness/
pwd                          # confirm woody-harness, not solo project
git status                   # must be clean
git pull --ff-only origin main
ls docs/                     # baseline: TUTORIAL/HARNESS_ETHOS/TROUBLESHOOTING/MEMORY_SYSTEM should NOT exist yet
ls .claude/commands/         # baseline: inbox.md / codex-audit.md / phase-gate.md exist; resume.md does NOT yet
```
If working tree dirty or pull conflicts — STOP and report.

## Commit convention (unchanged from 4a)
- Subject only, no co-author trailer.
- Types: `feat`, `fix`, `docs`, `chore`.

## Reference material to read BEFORE writing
Read these so docs stay consistent:
1. `README.md` (rewritten in 4a)
2. `docs/WORKFLOW.md` — plan/execute split source of truth
3. `docs/PHASE_GATING.md` — what counts as "shipped"
4. `docs/CODEX_AUDIT.md` — second-opinion review
5. `docs/SMOKE_TESTING.md` — real-machine verification
6. `templates/CLAUDE.md`, `templates/RESUME.md`, `templates/memory/*.md` — what bootstrap drops in
7. `bootstrap.sh` — what actually happens when user runs it
8. `.claude/commands/inbox.md`, `phase-gate.md`, `codex-audit.md` — existing slash commands

If any new doc contradicts existing files, NOTE in final report — don't silently fix.

---

## Deliverables — 7 atomic commits, in order

### Commit 1 — `docs/TUTORIAL.md`
**Purpose**: 30-minute walkthrough from "git clone" to "first phase shipped".

**Required H2 sections** (use these exactly):

1. `## Prerequisites` — `claude` CLI, `gh` authed, bash 4+/zsh, macOS or Linux (Windows: WSL only — note explicitly), GitHub account
2. `## Step 1 — Clone the harness (one-time)` — `git clone https://github.com/woodylin0920-bit/woody-harness ~/woody-harness` + why clone-once-then-bootstrap pattern
3. `## Step 2 — Bootstrap a new project` — `bash ~/woody-harness/bootstrap.sh hello-world` + list actual files copied (read bootstrap.sh to be accurate) + cd in
4. `## Step 3 — Open two Claude Code sessions` — Terminal A `claude` (Opus planner), Terminal B `claude --model sonnet` + `/effort medium` (executor); both same cwd; why split → see WORKFLOW.md
5. `## Step 4 — Plan your first feature` — describe wish to planner ("add a hello.sh that prints args"); planner replies with structured prompt; key teaching: prompts are explicit because Sonnet is literal
6. `## Step 5 — Hand off via _inbox.md` — planner writes prompt to `docs/prompts/_inbox.md`; show concrete 5-10 line example prompt (working dir / deliverable / commit message / constraints)
7. `## Step 6 — Execute with /inbox` — executor types `/inbox`, Sonnet reads + commits atomically, user watches but doesn't intervene
8. `## Step 7 — Phase gate before shipping` — `/phase-gate` reads PHASE_GATING.md checklist; pass = push, fail = back to planner
9. `## Step 8 — (Optional) Codex audit` — `/codex-audit` for adversarial review; when to use: auth/data/migration changes
10. `## Step 9 — Push + iterate` — `git push origin main`, loop back to Step 4
11. `## What you just learned` — 3-bullet recap (split / inbox / phase gate) + pointer to HARNESS_ETHOS.md
12. `## Next` — read WORKFLOW.md, skim FUTURE.md, open issue if anything broke

**Length**: 250-400 lines. Concrete > abstract. Show actual command outputs (~2 fenced blocks per step max).
**Commit**: `docs: add TUTORIAL.md — 30-min walkthrough from clone to first ship`

---

### Commit 2 — `docs/HARNESS_ETHOS.md`
**Purpose**: One-page philosophy doc.

**Structure** (9 numbered H2 sections + H1 title):

```markdown
# Harness ethos

Why woody-harness looks the way it does. Read once.

## 1. Bash + markdown only
[2-3 paragraphs: zero deps = forks always work; markdown = both human + LLM read it;
no version skew; debuggable with `cat`]

## 2. Atomic commits
[One logical change per commit: revertable, bisectable, self-documenting via subject lines.
Reference: `git log --oneline` of woody-harness itself as canonical example]

## 3. Phase-gated shipping
[Every phase ends with PHASE_GATING.md gate. Half-shipped = not shipped.
Either it passes the gate or it stays on the branch.]

## 4. Plan / execute split
[Opus plans + Sonnet executes. Different cognitive modes. Sonnet is literal —
that's a feature: forces planner to be explicit. See WORKFLOW.md.]

## 5. Memory-first context
[Context lives in `~/.claude-work/.../memory/` not chat scrollback.
Sessions are cheap, context is precious. Memory is checked-in-able if desired.
See MEMORY_SYSTEM.md.]

## 6. Boil the lake on P0 before P1
[Ship-ready before scope-creep. solo project Phase 1 had 6 P0 fixes shipped before
Phase 2 OCR began. Don't carry tech debt across phase boundaries.]

## 7. Real-machine smoke > CI green
[CI is a sieve, not a sign-off. Real-machine = your laptop. See SMOKE_TESTING.md.]

## 8. Fork-friendly by default
[MIT, zero deps, no telemetry, no service deps. If GitHub goes dark, your fork still works.]

## 9. What this is NOT
[Not an agent framework. Not taskmaster. Not a productivity hack.
A workflow scaffold for one person + Claude Code. For orchestration → langgraph / autogen / etc.]
```

**Tone**: terse, opinionated, imperative or first-person plural. No corporate hedging. Reference real solo project incidents where it sharpens the point.
**Length**: 150-250 lines.
**Commit**: `docs: add HARNESS_ETHOS.md — 9 principles behind the framework`

---

### Commit 3 — `docs/TROUBLESHOOTING.md`
**Purpose**: Known gotchas. Each entry: symptom + cause + fix.

**Format**:
```markdown
### <one-line symptom>

**Symptom**: <what user sees>
**Cause**: <why>
**Fix**: <commands or steps>
```

**Required entries (in order)**:
1. `gh: command not found` / `gh auth status` fails → install + `gh auth login`
2. `bootstrap.sh` leaves `{{PROJECT_NAME}}` literal → upgrade to commit `e961c2e`+, or run `find . -type f -exec sed -i '' 's/{{PROJECT_NAME}}/yourname/g' {} +` (BSD sed needs `''`)
3. macOS sed `-i` examples fail on Linux → BSD `sed -i ''` vs GNU `sed -i`. Docs use BSD form; Linux users adjust.
4. Python venv inside iCloud Drive folder breaks → iCloud trap. Move project out of synced folders, or place venv at `~/.venvs/<project>`.
5. `/inbox` says "no prompt found" → cwd mismatch. Both sessions same project root. `pwd` to verify.
6. Executor ignores planner's prompt → wrong model. Confirm `claude --model sonnet`. Opus tends to plan instead of execute.
7. `git push` rejected, "tip behind" → planner committed in another session. `git pull --ff-only` then retry.
8. Memory not auto-loading → memory dir path must match `~/.claude-work/projects/-<absolute-path-with-dashes>/memory/`. Derive with `pwd | sed 's|/|-|g'`.
9. `/phase-gate` fails on fresh project → expected. Gate looks for tests + smoke. Populate or skip for bootstrap commit.
10. `/codex-audit` says codex not installed → install OpenAI codex CLI per their docs; not bundled.
11. SessionStart briefing didn't print after bootstrap → confirm `.claude/settings.json` got copied (it should after Phase 4b commit 7) and that `RESUME.md` exists in cwd.
12. `/resume` slash command not found → confirm `.claude/commands/resume.md` exists in cwd; if bootstrapped before Phase 4b, manually copy from harness or re-bootstrap.

**Final section**: `## Still stuck?` — open issue using bug template; include `git log --oneline -5` + `bash --version`.
**Length**: ~150-220 lines.
**Commit**: `docs: add TROUBLESHOOTING.md — 12 known gotchas with fixes`

---

### Commit 4 — `CONTRIBUTING.md` (repo root)
**Purpose**: Lower the bar for fork-back-PR pattern.

**Sections**:
1. `## This is a personal framework — but PRs are welcome` — bias toward solo Claude Code users; what's wanted (bug fixes, doc clarifications, slash command improvements, troubleshooting from real friction)
2. `## Fork → adapt → upstream` — fork is primary use case; if your adaptation generalizes → PR; if project-specific → keep in fork
3. `## Contribution areas` — `templates/`, `docs/`, `.claude/commands/`, `bootstrap.sh`, `scripts/`. **Off-limits without discussion**: dependency additions, language additions
4. `## Commit convention` — subject-only, types `feat|fix|docs|chore`, no co-author trailer; example `feat: add /smoke slash command for one-shot smoke runs`
5. `## PR checklist` — atomic / template change tested via `bash bootstrap.sh /tmp/test-bootstrap` / no broken internal links / no new deps without prior issue / CHANGELOG `## [Unreleased]` updated
6. `## Issue first for big changes` — anything > 100 LOC or multi-subsystem → issue first
7. `## Code of conduct` — one sentence: be kind, assume good faith, contributions welcome from anyone

**Length**: 80-150 lines.
**Commit**: `docs: add CONTRIBUTING.md — fork-back-PR pattern + PR checklist`

---

### Commit 5 — `docs/MEMORY_SYSTEM.md`
**Purpose**: Explain the auto-loaded memory layer — what it is, who reads it, how to add to it.

**Required H2 sections**:

1. `## What is auto-memory` — Claude Code auto-loads `~/.claude-work/projects/<slug>/memory/MEMORY.md` every session. Slug = absolute project path with `/` → `-`. Auto-derived in `bootstrap.sh`.
2. `## The 4 memory types` — table or bullets:
   - `user` — who you are, how you work
   - `feedback` — corrections / validated approaches (rule + Why + How to apply)
   - `project` — current state, deadlines, decisions
   - `reference` — pointers to external systems (Linear, Grafana, etc.)
3. `## Who reads what (planner vs executor)` — **reproduce this matrix**:

   | Memory file               | Planner (Opus)                                 | Executor (Sonnet)                       |
   |---------------------------|------------------------------------------------|-----------------------------------------|
   | `feedback_terse_zh`       | conversation style                             | report style ✅                         |
   | `feedback_workflow_split` | knows own role (don't execute)                 | knows own role (execute fully)          |
   | `feedback_model_split`    | knows other side is literal → write detailed   | knows self is literal → don't 2nd-guess |
   | `env_paths`               | reference correct venv when writing prompt     | use correct venv when running ✅        |
   | `project_<name>`          | full project context                           | not strictly needed                     |
   | `project_current_handoff` | knows progress → writes next prompt            | not needed                              |

   **Bottom line**: executor minimum = `feedback_terse_zh` + `feedback_model_split` + `env_paths`. Planner reads everything. Both sessions auto-load same memory dir; what matters is *which entries each role acts on*.

4. `## Inbox vs memory — complementary, not redundant` — inbox = "this task", memory = "permanent style + environment + role". Both needed.
5. `## What bootstrap.sh ships` — list templates copied to memory dir (see `templates/memory/`): `MEMORY.md`, `feedback_terse_zh.md`, `feedback_workflow_split.md`, `feedback_model_split.md`, `env_paths.md`. Localize manually after bootstrap (e.g. user role / project context).
6. `## Adding a new memory` — file with frontmatter (`name`, `description`, `type`) + body; add one-line pointer in `MEMORY.md` index. ~150 char per line in MEMORY.md (lines after 200 truncated).
7. `## When to update / remove` — memory rots. If reality changes, update or delete the entry rather than acting on stale info.
8. `## Auto-briefing on session start` — pointer to `/resume` slash command + SessionStart hook (commits 6+7) for "where are we" briefing without typing.

**Length**: 180-280 lines.
**Commit**: `docs: add MEMORY_SYSTEM.md — auto-memory roles + planner/executor matrix`

---

### Commit 6 — `.claude/commands/resume.md` (new slash command at harness root)
**Purpose**: Active "where are we" briefing without waiting for SessionStart hook. Usable in both harness dev and bootstrapped projects.

**File path**: `/Users/woody/Desktop/repo/public/woody-harness/.claude/commands/resume.md`

**File content** (繁中描述以匹配既有 inbox.md 風格):
```markdown
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
```

**Commit**: `feat: add /resume slash command for active progress briefing`

---

### Commit 7 — `.claude/settings.json` + `bootstrap.sh` wiring
**Purpose**: SessionStart hook auto-prints briefing on every new Claude Code session in any bootstrapped project; fix bootstrap to copy `.claude/settings.json` + all slash commands (currently only `inbox.md` is copied; `resume.md`, `phase-gate.md`, `codex-audit.md` are missed).

**File 1**: `/Users/woody/Desktop/repo/public/woody-harness/.claude/settings.json`
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "test -f RESUME.md && (echo '=== RESUME.md (head) ==='; head -30 RESUME.md; echo ''; echo '=== recent commits ==='; git log --oneline -5 2>/dev/null) || true"
          }
        ]
      }
    ]
  }
}
```
Test that this is valid JSON. The `|| true` ensures hook never fails the session.

**File 2**: edit `bootstrap.sh` — locate the `# Copy templates` block (currently around line 24-31). REPLACE the single `cp .claude/commands/inbox.md` line with:
```bash
# Copy all slash commands + settings
cp "$HARNESS_DIR/.claude/commands/inbox.md" .claude/commands/
cp "$HARNESS_DIR/.claude/commands/resume.md" .claude/commands/
cp "$HARNESS_DIR/.claude/commands/phase-gate.md" .claude/commands/
cp "$HARNESS_DIR/.claude/commands/codex-audit.md" .claude/commands/
cp "$HARNESS_DIR/.claude/settings.json" .claude/settings.json
```

Also add a verification line at the end of `bootstrap.sh` (just before the `[bootstrap] Done.` echo):
```bash
# Sanity check — RESUME.md is required for SessionStart briefing
test -f RESUME.md || { echo "[bootstrap] WARN: RESUME.md missing — SessionStart briefing will be silent" >&2; }
```

**Verification BEFORE committing commit 7**:
```bash
# 1. JSON parse
python3 -c "import json; json.load(open('.claude/settings.json'))" && echo "settings.json valid"

# 2. Dry-run bootstrap to /tmp (bootstrap creates $(pwd)/<name>, so cd to /tmp first)
cd /tmp && rm -rf wh-test
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh wh-test
ls /tmp/wh-test/.claude/commands/
ls -la /tmp/wh-test/.claude/settings.json
python3 -c "import json; json.load(open('/tmp/wh-test/.claude/settings.json'))" && echo "copied settings.json valid"
cd /Users/woody/Desktop/repo/public/woody-harness/
```
Expected: `inbox.md  resume.md  phase-gate.md  codex-audit.md` and a valid copied settings.json. If anything diverges, FIX bootstrap.sh and re-run dry-run before committing.

**Commit**: `feat: SessionStart auto-briefing hook + bootstrap copies all commands + settings.json`

---

## After all 7 commits
```bash
git log --oneline -15
git push origin main
git status
```

## Hard constraints
1. **NO co-author / Claude trailers** in commits.
2. **DO NOT** modify existing docs (WORKFLOW.md, PHASE_GATING.md, CODEX_AUDIT.md, SMOKE_TESTING.md, FUTURE.md, README.md, CHANGELOG.md, CONTRIBUTING.md once written) — only ADD new files OR modify `bootstrap.sh` per commit 7.
3. **DO NOT** start Phase 4c (`examples/hello-cli/`) — separate prompt.
4. **DO NOT** invent slash commands or features that don't exist. If TUTORIAL/TROUBLESHOOTING needs to reference something not built, omit or point to FUTURE.md.
5. **DO NOT** add screenshots / images / non-text assets.
6. **DO NOT** modify the existing slash command files (`.claude/commands/inbox.md`, `phase-gate.md`, `codex-audit.md`) — they are stable.
7. If commit 7's dry-run bootstrap fails, STOP and report — do not commit broken bootstrap.
8. If you find contradictions between new docs and existing files, NOTE in final report — don't silently reconcile.

## Reply format when done
```
✅ Phase 4b shipped — 7 commits + push

<git log --oneline -15>

<git status>

Bootstrap dry-run: <pass|fail with detail>
Contradictions found: <list or "none">

Ready for Phase 4c gate (examples/hello-cli/ minimal demo project).
```

Then stop. Do NOT proactively start 4c.
