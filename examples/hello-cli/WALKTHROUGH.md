# WALKTHROUGH — how hello-cli got built

> Walkthrough is real session output from Claude Code. The narrative still applies regardless of model — substitute whatever planner/executor pairing you use.

This is a narrative of a complete plan/execute cycle using Tandem. Follow along
to see how the pieces fit: bootstrap, planner prompt, executor run, smoke test, RESUME update.

---

## The setup

The user ran `bash ~/Tandem/bootstrap.sh hello-cli` from their project directory.
Bootstrap produced this directory structure:

```
hello-cli/
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
        ├── _inbox.md              # cross-session mailbox (empty)
        └── README.md              # explains the prompts/ folder
```

Bootstrap also:
- Created a memory directory at `~/.claude-work/projects/<slug>/memory/` with four starter memories.
- Ran `git init` and made an initial `chore: bootstrap from Tandem` commit.

The state of this example directory at commit 1 (`feat: examples/hello-cli/ — bootstrapped skeleton`)
captures exactly this post-bootstrap, pre-feature state.

---

## The plan (planner Opus session)

The user opened an Opus session (`claude`) and said:

> "Add a hello CLI — bash script that takes a name argument and greets the user."

Opus thought through the scope (one bash script, one test, two atomic commits), wrote a
self-contained 44-line prompt, and saved it to `docs/prompts/_inbox.md`.

That prompt is preserved at `docs/prompts/2026-04-28-add-hello-script.md`
(commit 2 of this directory). Key things the planner specified:

- Exact file location: `hello.sh` at project root
- Exact behavior: exit 0 with greeting, exit 1 with usage if no arg
- Exact commit messages: `feat: add hello.sh greeting CLI` and `test: smoke test for hello.sh`
- Hard constraints: no external deps, no extra comments, run test before reporting done

The planner left nothing to the executor's judgment. Explicit beats implicit.

---

## The execution (executor Sonnet session)

The user opened a Sonnet session (`claude --model sonnet`) and typed `/inbox`.

Sonnet read `docs/prompts/_inbox.md` and executed literally:

1. Pre-flight: confirmed `pwd` ends in `/hello-cli`, `git status` was clean.
2. Wrote `hello.sh` with the exact content specified.
3. Ran a quick sanity check: `bash hello.sh world` → `Hello, world!`
4. Made commit 1: `feat: add hello.sh greeting CLI`
5. Wrote `tests/test_hello.sh` with two test cases.
6. Ran `bash tests/test_hello.sh` → `PASS: 2/2 tests`
7. Made commit 2: `test: smoke test for hello.sh`
8. Archived `_inbox.md` → `docs/prompts/2026-04-28-add-hello-script.md`
9. Cleared `_inbox.md` (back to empty)
10. Updated `RESUME.md` to reflect Phase 1 shipped.

Total wall time: under 2 minutes. Zero back-and-forth.

The state of this example directory at commit 3 (`feat: examples/hello-cli/ — ship hello.sh + smoke test`)
captures the post-execution state.

---

## The diff

Conceptual `git log --oneline` of the hello-cli demo project (as narrated commits):

```
chore: bootstrap from Tandem
feat: add hello.sh greeting CLI
test: smoke test for hello.sh
```

The artifact produced (`hello.sh`):

```bash
#!/usr/bin/env bash
# hello.sh — print a greeting. Usage: bash hello.sh <name>
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: bash hello.sh <name>" >&2
    exit 1
fi

echo "Hello, $1!"
```

Ten lines. One responsibility. Testable in one command. That is a ship-ready Phase 1.

---

## What you just saw

- **Plan/execute split**: Opus wrote a precise spec; Sonnet executed it literally. No context bleed, no re-deliberation.
- **Atomic commits**: each commit = one logical unit (`hello.sh` separately from its test). Revertable independently.
- **Smoke test as gate**: `bash tests/test_hello.sh` ran before the phase was declared done. No "it should work" handwaving.

---

## Doing this yourself

Read `docs/TUTORIAL.md` in the Tandem root for a full 30-minute walkthrough:
cloning the harness, bootstrapping your own project, opening two sessions, planning your
first feature, running `/inbox`, and gating with `/phase-gate`.

This example is a static snapshot — for a real project you would also have:
- A `~/.claude-work/projects/<slug>/memory/` directory with auto-loaded context.
- A real `.git` history (not just narrated commits).
- A GitHub remote to push to after the phase gate passes.
