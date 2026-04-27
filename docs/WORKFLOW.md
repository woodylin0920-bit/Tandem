# Tandem Workflow

This is the day-to-day flow battle-tested on solo project work (1 week, 4 phases, 6 P0 safety fixes resolved).

## The two-session split

```
┌─────────────────────────┐         ┌──────────────────────────┐
│  Planning session       │         │  Execution session       │
│  (terminal Opus 4.7)    │         │  (terminal Sonnet)       │
│                         │         │                          │
│  - strategy, tradeoffs  │ writes  │  - reads /inbox          │
│  - prompt authoring     │ ──────► │  - commits + pytest      │
│  - codex audit results  │ _inbox  │  - pushes to remote      │
│  - decisions            │         │  - archives prompt       │
│                         │ ◄────── │                          │
│  - interprets results   │ pastes  │  - reports back          │
└─────────────────────────┘         └──────────────────────────┘
```

## Cycle per phase

1. **Plan** in Opus session: pick next phase, decide tradeoffs, get user input
2. **Write prompt**: Opus writes to `docs/prompts/_inbox.md`, structure:
   - PRE-FLIGHT block
   - "Do not re-litigate decisions" boilerplate
   - 5-6 atomic commits with inlined code + commit messages
   - Verification commands
   - Reporting template
3. **Execute** in Sonnet session: type `/inbox`, walk away
4. **Report**: Sonnet pushes commits, archives `_inbox.md` to `<descriptive-name>.md`, summarizes
5. **Interpret**: paste report back to Opus, get verdict + next step

## Why this works

- **No context bleed**: Sonnet doesn't carry planning rationale; Opus doesn't carry execution detail
- **Atomic prompts**: each `_inbox.md` is one logical unit, revertable
- **Self-documenting**: `docs/prompts/<phase-name>.md` archive shows project history
- **Cheap iteration**: Sonnet is fast + cheap; Opus only spent on hard thinking

## Rules of thumb

- Every prompt **starts with PRE-FLIGHT** check (env, baseline tests green, cwd)
- Every prompt **ends with a reporting template** (commit SHAs, test counts, smoke observations)
- Sonnet **never makes architecture decisions** — those happen in Opus session
- Pytest is **always green** before / after each commit (no "fix later" tech debt)
- Codex audit before any user-facing ship (not in Phase 1, see Phase 2)
