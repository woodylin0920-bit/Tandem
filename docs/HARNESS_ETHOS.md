# Harness ethos

Why Tandem looks the way it does. Read once.

---

## 1. Bash + markdown only

The entire harness is `bootstrap.sh`, a handful of `.md` files, and one `settings.json`. No package manager, no lock file, no runtime version to pin.

This is a deliberate constraint. Zero dependencies means a fork always works: `git clone`, `bash bootstrap.sh`, done — no `npm install`, no venv setup, no version mismatch between your machine and mine. If a dependency breaks (and they do), you can debug with `cat` instead of diving into `node_modules`.

Markdown is the right format here because both humans and LLMs read it without tooling. A `WORKFLOW.md` opened in a code editor looks fine. The same file pasted into a Claude prompt context also works fine. There is no "view-source" mismatch.

---

## 2. Atomic commits

One logical change per commit. Not "today's work." Not "WIP." Not "fix stuff."

Atomic commits are revertable: `git revert <sha>` undoes exactly one thing. They are bisectable: `git bisect` can find the exact commit that introduced a regression. And they are self-documenting: `git log --oneline` of Tandem itself reads like a changelog.

```
8b92644 docs: capture multi-worker dashboard idea in FUTURE.md (deferred)
3d1b14b feat: Tandem Phase 1 — bootstrap + inbox + memory templates
```

That is enough context to understand the project history without opening a single file. Write commits as if the subject line is all the future maintainer will see — because often it is.

---

## 3. Phase-gated shipping

Every phase ends with a `/phase-gate` check. Half-shipped = not shipped. Either a phase passes all three gates (tests green, SLO met, clean push state) or it stays on the branch.

The gate exists because "I'll fix it later" doesn't happen. A recent solo project learned this the hard way: six P0s discovered by codex audit after "shipping" Phase 1 — prompt injection, silent device failures, a recursive crash in event logging, no watchdog, a bad error path, a temp file leak. None of those would have shipped if a gate had existed earlier.

Fix before ship. The gate is the forcing function.

---

## 4. Plan / execute split

Opus plans. Sonnet executes. The two sessions never run in the same terminal.

Sonnet is more literal than Opus — that is a feature, not a limitation. It forces the planner to be explicit. If Sonnet misunderstands a prompt, the prompt was ambiguous. Fix the prompt, not Sonnet.

Concretely: Opus writes a fully self-contained `_inbox.md` prompt with exact file content, exact commit messages, exact verification commands. Sonnet reads it and executes without asking questions. No context bleed, no re-deliberation.

See `WORKFLOW.md` for the session diagram and rules of thumb.

---

## 5. Memory-first context

Context lives in `~/.claude-work/projects/<slug>/memory/`, not in chat scrollback.

Chat scrollback dies when you close the terminal. Memory persists. The harness ships four memory templates on bootstrap: terse communication style, workflow split roles, model split behavior, and environment paths. These load automatically on every new session — Opus and Sonnet both start with the same shared context without you pasting anything.

Memory is checked-in-able if you want it in the repo. By default it lives outside (so it can cover multiple projects without duplication). Add entries as you learn things — what went wrong, what your venv path is, what the current handoff state is. Remove stale entries before they mislead you.

See `docs/MEMORY_SYSTEM.md` for the four types, the planner/executor read matrix, and how to add entries.

---

## 6. Boil the lake on P0 before P1

Ship-ready before scope-creep. When a recent solo project's Phase 2 was ready to start, the codex audit surfaced six P0s from Phase 1 that had slipped through. All six were fixed before a single line of Phase 2 code was written.

That is the right order. Carrying known P0s across a phase boundary compounds them: Phase 2 code builds on Phase 1 assumptions, and if those assumptions are wrong, Phase 2 is wrong too. Fix the foundation, then build.

The same applies here: don't start Phase 4c (example project) until the Phase 4b docs are done and committed. Sequence matters.

---

## 7. Real-machine smoke > CI green

CI is a sieve, not a sign-off.

pytest green means the logic is correct under the test harness's assumptions. It does not mean the hardware works, the OS behaves, or the external dependency responds the way the mock said it would. For accessibility-critical or safety-critical projects, silent failure is a safety issue, not a test metric. A failing audio cue with no error feedback is a P0 regardless of what pytest says.

Every non-trivial project gets a `scripts/smoke.sh`: a driver that prompts the developer to do real-machine observations (hear the audio, see the window, watch the log) and answers y/n. Any ❌ → exit 1. It runs once per phase ship, not in CI.

See `docs/SMOKE_TESTING.md`.

---

## 8. Fork-friendly by default

MIT license. Zero deps. No telemetry. No service accounts. No cloud hooks that require your credentials to function.

If GitHub goes dark tomorrow, your fork still works: `bootstrap.sh` reads from your local clone, memory lives in `~/.claude-work`, slash commands are markdown files in `.claude/commands/`. Nothing phones home.

This is intentional. A developer workflow tool should not have SLAs. Fork it, strip the parts you don't need, add the parts that fit your project. If your adaptation generalizes, open a PR. If it's project-specific, keep it in your fork.

---

## 9. What this is NOT

Not an agent framework. Not taskmaster. Not a productivity app with a dashboard.

Tandem is a workflow scaffold for **one person + Claude Code**. The "orchestration" is you — picking what to build, deciding tradeoffs, writing prompts that Sonnet can execute. The harness provides the folder structure, the handoff convention, the memory templates, and the phase gate. You provide the judgment.

For multi-agent orchestration → langgraph, autogen, or similar. For automated task management → taskmaster. For Claude Code keyboard shortcuts and settings → `/config`. Those are different tools for different problems.

This tool is for the developer who wants to move fast with AI assistance without giving up clarity about what is happening and why.
