---
name: model split — Opus plans, Sonnet executes
description: user pairs Opus 4.7 (planning, prompt-writing, decisions) with Sonnet (execution, commits, pytest). Tune prompts for the receiving model.
type: feedback
---

User runs two parallel Claude sessions:
- **Planning: Opus 4.7** — reasoning-heavy: phase design, model selection, tradeoffs, prompt authoring.
- **Executor: Sonnet** — receives prompts, runs git/pytest/pip, ships commits.

**Why:** Cost/quality split. Opus where reasoning matters, Sonnet where speed + structured execution matters.

**How to apply:**
- When writing prompts for the executor session, optimize for **Sonnet**:
  - Make decisions **explicit** in the prompt. Don't leave room for "use your judgment". Sonnet is more literal than Opus.
  - Inline all code blocks (don't say "write a reasonable test"; show the exact test).
  - Pre-write commit messages.
  - Pre-specify verification commands.
- Recommended `/effort` settings:
  - Planning Opus: `high` (default) — bump to `xhigh` for hard architecture decisions
  - Executor Sonnet: `medium` (or `low` for trivial tasks)
- Do not assume Sonnet has access to the planning conversation's context. Each prompt must be fully self-contained including read-list of files (README, RESUME, related modules).
