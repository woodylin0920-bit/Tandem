# Harness ethos

Why Tandem looks the way it does. Read once.

---

## 1. Bash + markdown only

The entire harness is `bootstrap.sh`, a handful of `.md` files, and one `settings.json`. No package manager, no lock file, no runtime version to pin.

This is a deliberate constraint. Zero dependencies means a fork always works: `git clone`, `bash bootstrap.sh`, done — no `npm install`, no venv setup, no version mismatch between your machine and mine. If a dependency breaks (and they do), you can debug with `cat` instead of diving into `node_modules`.

Markdown is the right format here because both humans and LLMs read it without tooling. A `WORKFLOW.md` opened in a code editor looks fine. The same file pasted into a model's prompt context also works fine. There is no "view-source" mismatch.

And because the entire interface is markdown, the framework isn't bound to one AI vendor. Memory files, inbox prompts, slash commands — all plain text. Tandem ships with Claude Code as the primary example because that's what I use, but porting to a different model is mechanical: read the same files, produce the same outputs.

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

The gate exists because "I'll fix it later" doesn't happen. Six P0 issues surfaced via codex audit after Phase 1 was "done" on a real solo project (see [ATTRIBUTION.md](../ATTRIBUTION.md)). All six were fixed before any Phase 2 code was written. Carrying known P0s across a phase boundary compounds them.

Fix before ship. The gate is the forcing function.

---

## 4. Plan / execute split

A planner session writes prompts. An executor session ships them. The two never run in the same terminal.

In my setup the planner is Claude Code with Opus and the executor is Claude Code with Sonnet — Sonnet's literalness is a feature, not a limitation. It forces explicit prompts; if the executor misunderstands, the prompt was ambiguous. Fix the prompt, not the model.

But the split is the principle, not the model pairing. Any pair where one side is reasoning-stronger (planner) and the other is execution-strong (executor) works — Claude/Codex, Claude/Claude, two human-AI pairs across timezones, etc. The prompt is just markdown.

Concretely: planner writes a fully self-contained `_inbox.md` prompt with exact file content, exact commit messages, exact verification commands. Executor reads it and ships without asking questions. No context bleed, no re-deliberation.

See `WORKFLOW.md` for the session diagram.

---

## 5. Memory-first context

Context lives in `~/.claude-work/`, not in chat scrollback. Two layers:

- `~/.claude-work/_shared/memory/` — preferences and workflow rules that apply to **every** project. Terse-Mandarin replies, planner/executor split, macOS notification quirks, "don't silently continue on error" — these are about *me*, not about any one project.
- `~/.claude-work/projects/<slug>/memory/` — current handoff state, phase progress, project-specific decisions. Lives per-project.

Shared layer symlinks into every project's memory dir. Add a feedback memory once, get it everywhere I work. **This is the longest-running win of using Tandem**: every project starts already understanding my conventions. The next blank-slate session is many projects ago, not this morning.

See `docs/SHARED_MEMORY.md` for the layer architecture and `docs/MEMORY_SYSTEM.md` for the four memory types.

---

## 6. Boil the lake on P0 before P1

Ship-ready before scope-creep. Six P0 issues surfaced via codex audit after Phase 1 was "done" on a real solo project (see [ATTRIBUTION.md](../ATTRIBUTION.md)). All six were fixed before a single line of Phase 2 code was written.

That is the right order. Carrying known P0s across a phase boundary compounds them: Phase 2 code builds on Phase 1 assumptions, and if those assumptions are wrong, Phase 2 is wrong too. Fix the foundation, then build.

The same applies here: don't start Phase 4c (example project) until the Phase 4b docs are done and committed. Sequence matters.

---

## 7. Real-machine smoke > CI green

CI is a sieve, not a sign-off.

pytest green means the logic is correct under the test harness's assumptions. It does not mean the hardware works, the OS behaves, or the external dependency responds the way the mock said it would. For projects where silent failure is a real risk (hardware control, side effects on real users, anything where "green test, broken behavior" has cost), pytest doesn't tell you the truth.

Every non-trivial project gets a `scripts/smoke.sh`: a driver that prompts the developer to do real-machine observations (hear the audio, see the window, watch the log) and answers y/n. Any ❌ → exit 1. It runs once per phase ship, not in CI.

See `docs/SMOKE_TESTING.md`.

---

## 8. Fork-friendly by default

MIT license. Zero deps. No telemetry. No service accounts. No cloud hooks that require your credentials to function.

If GitHub goes dark tomorrow, your fork still works: `bootstrap.sh` reads from your local clone, memory lives in `~/.claude-work`, slash commands are markdown files in `.claude/commands/`. Nothing phones home.

This is intentional. A developer workflow tool should not have SLAs. Fork it, strip the parts you don't need, add the parts that fit your project. If your adaptation generalizes, open a PR. If it's project-specific, keep it in your fork.

---

## 9. Cross-vendor quality gates

Quality assurance should not depend on a single vendor agreeing with itself.

Tandem ships `/codex-audit` as a slash command — at the end of each phase, OpenAI Codex reviews what Claude shipped against a 7-dimension prompt (`templates/prompts/CODEX_AUDIT.md`). The two systems disagree often enough that the audit catches real issues — bias overlap is lower than running two Claude sessions over the same code.

Same logic on the input side: any model that can read markdown can be a planner or executor. The framework doesn't require one vendor; it works because the *interface* is text, not because of any specific tool integration.

---

## 10. What this is NOT

Not an agent framework. Not taskmaster. Not a productivity dashboard.

Tandem is workflow scaffolding for **one engineer + their AI of choice**. The "orchestration" is you — picking what to build, deciding tradeoffs, writing prompts the executor session can ship without re-asking. The framework provides the folder structure, the handoff convention, the memory layer, and the phase gate. You provide the judgment.

For multi-agent orchestration → langgraph, autogen, similar. For task management → taskmaster. For Claude Code keyboard shortcuts → `/config`. Different tools, different problems.

This is for the engineer who wants to move fast with AI assistance without giving up clarity about what is happening and why.
