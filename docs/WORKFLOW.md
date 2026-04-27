# Tandem Workflow

This is the day-to-day flow Tandem is built around. The split is the principle — the specific model pairing is up to you. See [ATTRIBUTION.md](../ATTRIBUTION.md) for the project where this workflow originally crystallized.

## The two-session split

```
┌─────────────────────────┐         ┌──────────────────────────┐
│  Planning session       │         │  Execution session       │
│  (reasoning-strong)     │         │  (execution-strong)      │
│                         │         │                          │
│  - strategy, tradeoffs  │ writes  │  - reads /inbox          │
│  - prompt authoring     │ ──────► │  - commits + pytest      │
│  - codex audit results  │ _inbox  │  - pushes to remote      │
│  - decisions            │         │  - archives prompt       │
│                         │ ◄────── │                          │
│  - interprets results   │ pastes  │  - reports back          │
└─────────────────────────┘         └──────────────────────────┘
```

> In my setup the planning side is Claude Code with Opus and the executor is Claude Code with Sonnet. Any pair where one model reasons well and the other ships well works — Claude/Codex, Claude/Claude, two-vendor combos. The interface between them is just markdown.

## Cycle per phase

1. **Plan** in the planning session: pick next phase, decide tradeoffs, get user input
2. **Write prompt**: planner writes to `docs/prompts/_inbox.md`, structure:
   - `## Execution profile` block (model + effort + commits estimate) — see `docs/MODEL_GUIDE.md`
   - PRE-FLIGHT block
   - "Do not re-litigate decisions" boilerplate
   - 5-6 atomic commits with inlined code + commit messages
   - Verification commands
   - Reporting template
3. **Execute** in the executor session: type `/inbox`, walk away
4. **Report**: executor pushes commits, archives `_inbox.md` to `<descriptive-name>.md`, summarizes
5. **Interpret**: paste report back to the planner, get verdict + next step

## Why this works

- **No context bleed**: Sonnet doesn't carry planning rationale; Opus doesn't carry execution detail
- **Atomic prompts**: each `_inbox.md` is one logical unit, revertable
- **Self-documenting**: `docs/prompts/<phase-name>.md` archive shows project history
- **Cheap iteration**: Sonnet is fast + cheap; Opus only spent on hard thinking

## Rules of thumb

- Every prompt **starts with PRE-FLIGHT** check (env, baseline tests green, cwd)
- Every prompt **ends with a reporting template** (commit SHAs, test counts, smoke observations)
- The executor session **never makes architecture decisions** — those happen in the planner session.
- Tests are **always green** before / after each commit (no "fix later" tech debt)
- Codex audit before any user-facing ship (not in Phase 1, see Phase 2)
