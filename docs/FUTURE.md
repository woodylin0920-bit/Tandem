# woody-harness — Future Design Notes

Ideas captured during development, deferred until real demand surfaces. Each entry has trigger conditions — only build when those fire.

---

## Multi-worker orchestrator + dashboard

**Captured**: 2026-04-27 (during omni-sense + harness Phase 1 dev)

### The vision

```
┌─ Manager (Opus) ────────────────────────────┐
│ chats with user, writes prompts             │
└─────────────────────────────────────────────┘
   ↓ writes
┌─ Inboxes (filesystem mailbox) ──────────────┐
│  inbox-omni-sense.md                        │
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
│  ▼ omni-sense [working] commit 3/5 ...      │
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
