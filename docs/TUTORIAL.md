# Tutorial — 30 minutes from clone to first ship

This walks you from a fresh machine to a committed, phase-gated feature. Follow in order.

Estimated time: 20-30 minutes on first run, 5 minutes on subsequent projects.

---

## Prerequisites

Install these before starting:

- **`claude` CLI** — install via `npm install -g @anthropic-ai/claude-code` (or the Anthropic docs). Confirm: `claude --version`
- **`gh` CLI** — install via Homebrew (`brew install gh`) or the GitHub CLI docs. Authenticate: `gh auth login`
- **bash 4+ or zsh** — macOS ships with zsh by default; bash on Linux is typically 5+. Confirm: `bash --version`
- **macOS or Linux** — Windows: WSL2 only. Native Windows PowerShell is not supported; `set -euo pipefail` and `sed -i ''` behave differently.
- **GitHub account** — needed for `gh auth login` and pushing your project.

You do **not** need Python, Node, or any language runtime to run the harness itself. Those are project-specific.

---

## Step 1 — Clone the harness (one-time)

```bash
git clone https://github.com/woodylin0920-bit/woody-harness ~/woody-harness
```

Clone once to `~/woody-harness`. You will never `cd` into it during normal work — it is a template source that `bootstrap.sh` reads from.

Why clone-once-then-bootstrap:
- The harness directory stays stable as a reference.
- Bootstrap copies templates into each new project, so projects are self-contained.
- Updating the harness (`git pull` in `~/woody-harness`) does not break existing projects.

---

## Step 2 — Bootstrap a new project

Pick a project name (lowercase, hyphens ok):

```bash
cd ~/Desktop/repo          # or wherever you keep projects
bash ~/woody-harness/bootstrap.sh hello-world
cd hello-world
```

What bootstrap copies into `hello-world/`:

```
hello-world/
├── CLAUDE.md                      # Claude Code skill routing + workflow reminder
├── RESUME.md                      # work log template
├── .gitignore
├── .claude/
│   ├── commands/
│   │   ├── inbox.md               # /inbox slash command
│   │   ├── resume.md              # /resume slash command
│   │   ├── phase-gate.md          # /phase-gate slash command
│   │   └── codex-audit.md         # /codex-audit slash command
│   └── settings.json              # SessionStart hook for auto-briefing
└── docs/
    └── prompts/
        ├── _inbox.md              # cross-session mailbox (planner writes, executor reads)
        └── README.md              # explains the prompts/ folder
```

Memory files are also written to `~/.claude-work/projects/<slug>/memory/` — Claude Code auto-loads these every session.

Bootstrap also runs `git init` and makes an initial commit, so the project is immediately version-controlled.

Expected output:

```
[bootstrap] Creating /Users/you/Desktop/repo/hello-world...
[bootstrap] Done.

Next steps:
  cd hello-world
  # Terminal 1 (planning):
  claude   # Opus
  # Terminal 2 (execution):
  claude --model sonnet
  # In Sonnet session: /inbox after Opus writes a prompt

Memory dir: /Users/you/.claude-work/projects/-Users-you-Desktop-repo-hello-world/memory
```

---

## Step 3 — Open two Claude Code sessions

You need **two terminal windows**, both with `cd hello-world` (same project root).

**Terminal A — planner (Opus):**

```bash
claude
```

Opus 4.7 is the default model. This session handles strategy, tradeoffs, and prompt authoring. Do not run code here.

**Terminal B — executor (Sonnet):**

```bash
claude --model sonnet
```

After Sonnet opens, type `/effort medium` and press Enter. This session reads `_inbox.md` and executes literally.

Why split? See `docs/WORKFLOW.md` for the full rationale. Short version:
- Opus spends its reasoning budget on decisions, not execution.
- Sonnet spends its execution budget on commits, not re-deliberation.
- Context stays clean: planner doesn't carry execution noise; executor doesn't second-guess plans.

---

## Step 4 — Plan your first feature

In **Terminal A (Opus)**, describe what you want to build:

> "Add a `hello.sh` script that accepts a name argument and prints `Hello, <name>!`. Should error with a usage message if no argument given."

Opus will think through:
- What file to create (`scripts/hello.sh` or root-level)
- Edge cases (missing argument, spaces in name)
- Commit message convention
- Whether any tests should accompany it

Key teaching: Opus writes prompts that are **explicit** because Sonnet is literal. Don't assume Sonnet will infer intent — tell it the exact path, exact content, exact commit message. Leave nothing to judgment.

A good planner prompt looks like this:

```
Working dir: /Users/you/Desktop/repo/hello-world (confirm with pwd)

## Commit 1 — hello.sh

Create `hello.sh` in the repo root:

  #!/usr/bin/env bash
  set -euo pipefail
  if [ $# -lt 1 ]; then
    echo "Usage: hello.sh <name>" >&2
    exit 1
  fi
  echo "Hello, $1!"

Make it executable: chmod +x hello.sh

Verify: bash hello.sh World → "Hello, World!"
        bash hello.sh → exit 1 + usage on stderr

Commit: feat: add hello.sh greeting script
```

Short, unambiguous, self-contained. Sonnet reads this and commits it without asking questions.

---

## Step 5 — Hand off via _inbox.md

When Opus has written the prompt, write it to the inbox:

```bash
# In Terminal A (Opus): ask Opus to write the prompt directly to the file
# Or write it yourself in your editor
```

The file `docs/prompts/_inbox.md` is the cross-session mailbox. Opus writes to it; Sonnet reads it.

A minimal inbox entry looks like this (5-10 lines is enough for a simple task):

```markdown
## Commit 1 — hello.sh

Working dir: /Users/you/Desktop/repo/hello-world
Pre-flight: pwd; git status (must be clean)

Create `hello.sh` at repo root:
  #!/usr/bin/env bash
  set -euo pipefail
  [ $# -lt 1 ] && { echo "Usage: hello.sh <name>" >&2; exit 1; }
  echo "Hello, $1!"

chmod +x hello.sh
Verify: bash hello.sh World → "Hello, World!"
Commit: feat: add hello.sh greeting script
```

The more explicit the prompt, the less back-and-forth. State working directory, list every file to create or modify, show exact content, pre-write the commit message.

---

## Step 6 — Execute with /inbox

In **Terminal B (Sonnet)**, type:

```
/inbox
```

Sonnet reads `docs/prompts/_inbox.md` and executes the instructions literally:
1. Runs the pre-flight check (`pwd`, `git status`)
2. Creates files, writes content
3. Makes the commit
4. Archives `_inbox.md` to `docs/prompts/<descriptive-name>.md`
5. Clears `_inbox.md`
6. Reports back

You watch but do not intervene. If Sonnet gets confused or stalls, it means the prompt was ambiguous — note it and improve the next prompt in Opus.

---

## Step 7 — Phase gate before shipping

Before pushing anything to remote, run the phase gate in **Terminal B (Sonnet)**:

```
/phase-gate
```

The gate checks three things (see `docs/PHASE_GATING.md` for full spec):

1. **Tests green** — pytest passes, count ≥ baseline. (On a fresh project with no tests yet, you need to either add tests or explicitly acknowledge the skip.)
2. **SLO met** — if your phase introduced measurable latency or throughput changes, benchmark them against README's stated values.
3. **Clean push state** — `git log @{u}..HEAD` should be empty if you've already pushed, or have commits ready if you haven't.

Pass → proceed to Step 9.
Fail → paste the failure back to Opus (Terminal A), get a fix prompt, loop back to Step 6.

Half-shipped = not shipped. Either it passes the gate or it stays on the branch.

---

## Step 8 — (Optional) Codex audit

For any change that touches auth, data handling, user input, or migration logic, run:

```
/codex-audit
```

This triggers an adversarial review using OpenAI Codex (independent from Anthropic). Codex has found things like:

- OCR prompt injection paths
- Silent hardware failures (mic, camera) with no user feedback
- Recursive crash in logging
- Temp file leaks

When to use:
- Before shipping any auth or data-access change
- Before handing code to real users
- When the change feels risky but hard to articulate why

When to skip:
- Pure doc commits
- Formatting or rename refactors
- Config changes with no logic

Requires the `codex` CLI to be installed separately — not bundled with the harness.

---

## Step 9 — Push + iterate

```bash
git push origin main
```

Then loop back to Step 4. Opus plans the next feature, writes to `_inbox.md`, Sonnet executes.

Each iteration is one logical feature or fix. Keep `_inbox.md` single-purpose — one prompt, one archive file in `docs/prompts/`. The archive is your project history in plain English.

---

## What you just learned

Three things make this workflow different from raw Claude Code:

1. **Plan / execute split** — Opus and Sonnet have separate cognitive roles. The planner never runs code; the executor never makes decisions. Context stays clean on both sides.

2. **Inbox handoff** — `docs/prompts/_inbox.md` is the only communication channel between sessions. One explicit, self-contained prompt per task. Forces you to articulate intent before execution begins.

3. **Phase gate** — nothing ships until tests are green and the commit is clean. The gate is the forcing function that prevents "I'll fix it later" from accumulating across phases.

For the philosophy behind these choices, read `docs/HARNESS_ETHOS.md`.

---

## Next

- Read `docs/WORKFLOW.md` for the full two-session diagram and rules of thumb.
- Skim `docs/FUTURE.md` for deferred ideas (CI hooks, multi-worker dashboard, etc.) — don't implement these unless you need them.
- If anything broke or felt wrong during this tutorial, open an issue using the bug template: [github.com/woodylin0920-bit/woody-harness/issues](https://github.com/woodylin0920-bit/woody-harness/issues). Include `git log --oneline -5` and `bash --version`.
- Once your project has a few phases shipped, try `/resume` in your executor session for a quick "where are we" briefing.
- For memory system details (what gets auto-loaded, what each template means), read `docs/MEMORY_SYSTEM.md`.
