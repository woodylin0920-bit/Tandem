# woody-harness — Future Design Notes

Ideas captured during development, deferred until real demand surfaces. Each entry has trigger conditions — only build when those fire.

---

## Multi-worker orchestrator + dashboard

**Captured**: 2026-04-27 (during harness Phase 1 dev)

### The vision

```
┌─ Manager (Opus) ────────────────────────────┐
│ chats with user, writes prompts             │
└─────────────────────────────────────────────┘
   ↓ writes
┌─ Inboxes (filesystem mailbox) ──────────────┐
│  inbox-project-a.md                         │
│  inbox-harness-phase-N.md                   │
│  inbox-experiment-X.md                      │
└─────────────────────────────────────────────┘
   ↓ /inbox <name>
┌─ Worker 1 ──┐ ┌─ Worker 2 ──┐ ┌─ Worker 3 ──┐
│ Sonnet      │ │ Sonnet      │ │ Sonnet      │
│ status.json │ │ status.json │ │ status.json │
└─────────────┘ └─────────────┘ └─────────────┘
              ↓ status updates
┌─ Dashboard ─────────────────────────────────┐
│  ▼ project-a   [working] commit 3/5 ...     │
│  ▼ harness    [done]    all green ✓         │
│  ▼ experiment [blocked] needs decision      │
└─────────────────────────────────────────────┘
```

User can chat with manager + see all workers' state + (later) issue commands from dashboard.

### Three effort tiers

| Tier | Effort | What you get |
|---|---|---|
| 1. tmux + status log | 30 min | `.harness/status.log` + `tail -F` in pane. Plain text, zero new tools |
| 2. terminal TUI | half day | Python `textual` lib, kanban-style worker board, click for last 10 lines |
| 3. web dashboard | 1-2 days | FastAPI + tiny frontend, viewable from phone, can issue commands |

### Why deferred

- Real bottleneck for solo dev = **decision-making throughput**, not execution parallelism
- Most tasks have dependencies (Phase N → N+1) — illusion of speed if forced parallel
- Current 2-session split (Opus plan + Sonnet exec) hasn't been outgrown yet
- Cognitive overhead of N workers > value when you're the bottleneck

### Build trigger

Build Tier 1 (`.harness/status.log` + tmux config) when **first time running 3+ truly independent tasks in parallel for >1 hour**. Likely scenario: simultaneously maintaining 2 shipped projects + exploring a third.

Build Tier 2/3 only after Tier 1 has been used for ≥2 weeks and felt insufficient.

### Slash command extension

Multi-inbox version:
- `/inbox` → default inbox (single-worker mode, today's behavior)
- `/inbox <name>` → reads `docs/prompts/inbox-<name>.md`

Backwards-compatible. Add when implementing Tier 1.

### Where to land

woody-harness Phase 3 (automation / CI / notifications). Same family as push-notification work.

### Scaling models (added 2026-04-27)

When the dashboard finally lands, the underlying execution topology can be one of these:

| Model | Setup | Use case | Cognitive cost |
|---|---|---|---|
| **A. Project-level isolation** (today's default) | 1 plan + 1 exec per project, multiple projects = multiple pairs | solo dev with N independent projects | low |
| **B. Lane-based** | 1 plan + multiple lanes in same repo (`_inbox-feature.md`, `_inbox-bugfix.md`) on separate branches | solo dev parallel work in same repo | medium |
| **C. 1 planner + N parallel execs** | one Opus writes N inbox files, N Sonnets execute concurrently | unrelated independent tasks at once | medium-high (planner becomes bottleneck) |
| **D. Hierarchical** | super-manager → N sub-managers → workers | 4+ active projects, strategic vs tactical layering | high |

**Default = A.** Move to B/C/D only when you've felt the pain of A first.

**Key insight**: solo dev's bottleneck is decision throughput, not execution parallelism. C/D *seem* like speed-ups but you still write all the prompts yourself. Don't pre-build.

---

## CLI UI for end users (`harness` command)

**Captured**: 2026-04-27 (during positioning discussion — Q1 audience: solo founders + general engineers; Q5 success: others fork it)

### The vision

A single `harness` CLI command for end users, lower friction than learning the file conventions.

```bash
harness new <project>            # bootstrap (replaces bash bootstrap.sh)
harness inbox edit               # open _inbox.md in $EDITOR
harness inbox status             # what's queued? what archived recently?
harness inbox archive <name>     # archive current _inbox.md to <name>.md
harness gate                     # run phase-gate checks (pytest + benchmark + push status)
harness audit                    # invoke codex audit with template
harness audit --safety           # invoke safety audit variant
harness smoke                    # run scripts/smoke.sh
harness status                   # all active sessions across ~/Desktop/repo/* (multi-project view)
harness memory ls                # list memory entries
harness memory add <type>        # interactive memory entry creator
```

Two flavors:

- **Plain CLI** (subcommand-driven, like `gh` or `git`) — fast power-user usage
- **TUI mode** (`harness ui` opens textual interface) — discovery for new users, kanban-style project view

### Why this matters

Right now woody-harness is **file conventions + bash scripts**. To use it, you must know:
- where `_inbox.md` lives
- what slash commands exist
- how memory dir maps to project path
- which prompt template to copy

A `harness` CLI hides this — `harness inbox edit` Just Works regardless of cwd-confusion.

This is what makes the framework **forkable / shareable** (matches Q5 success metric):
- New user runs `pip install woody-harness` (or `brew install harness`)
- Reads README's quick-start: `harness new my-project`
- Doesn't need to learn the entire file taxonomy upfront — discovers it via `harness <subcommand> --help`

### Why deferred

- Phase 1-2 is still raw bash + markdown — proves the patterns work
- Adding CLI before patterns are stable = premature lock-in
- Need more usage data: which subcommands actually get used vs theoretical?

### Build trigger

Build when:
- Phase 1-4 templates have stabilized (no major churn in 1 month)
- You've onboarded 1 other person who used the bash version and complained about UX
- OR you find yourself writing the same `cat docs/prompts/_inbox.md` / `mv ... archive` shell snippets repeatedly

### Tech stack candidates

- **Python + Click + Textual** — Click for CLI, Textual for TUI. Most flexibility, biggest install footprint
- **Bun + ink (React)** — fashionable, fast, but ecosystem smaller for TUI
- **Pure bash + fzf** — lightest, no install, but caps out at simple subcommands
- **Rust + ratatui** — fastest, distributable as single binary, but slower to write

Recommend: **Python + Click** for v1 (CLI only, no TUI yet). Add Textual for TUI in v2 if usage demands.

### Where to land

Phase 5 (after Phase 4 onboarding work proves what subcommands users actually need).

Can also live in a separate repo: `woody-harness-cli` ← references the templates from `woody-harness`. Keeps the framework spec separate from the tool.

---

## (template — add new future ideas below)

### [Idea name]

**Captured**: [date] (context)

### The vision
...

### Why deferred
...

### Build trigger
...
