# Memory system

How auto-loaded memory works, what the bootstrap templates mean, and how to add or remove entries.

---

## What is auto-memory

Claude Code automatically loads `~/.claude-work/projects/<slug>/memory/MEMORY.md` at the start of every session. The `<slug>` is the absolute path of your project with `/` replaced by `-`.

Example: if your project lives at `/Users/you/Desktop/repo/hello-world`, the slug is `-Users-you-Desktop-repo-hello-world`, and the memory directory is:

```
~/.claude-work/projects/-Users-you-Desktop-repo-hello-world/memory/
```

`bootstrap.sh` derives this slug automatically and copies the four starter templates into it. After that, both your planning session (Opus) and executor session (Sonnet) start with that same memory context loaded — no manual pasting required.

---

## The 4 memory types

- **`user`** — who you are, how you work. Role, background, preferences that don't change per project.
- **`feedback`** — corrections and validated approaches. Each entry: rule + **Why:** + **How to apply:**. Both negative feedback ("don't do X") and positive confirmation ("yes, that approach was right") belong here.
- **`project`** — current state, decisions, deadlines, handoffs. Decays fast; keep it fresh or remove it.
- **`reference`** — pointers to external systems: Linear project names, Grafana dashboard URLs, Slack channels, internal wikis.

Every memory file has a frontmatter header:

```markdown
---
name: short name
description: one-line description — used to decide relevance
type: user | feedback | project | reference
---

[body content]
```

---

## Who reads what (planner vs executor)

Both sessions auto-load the same memory directory. What matters is which entries each role actually acts on.

| Memory file               | Planner (Opus)                                       | Executor (Sonnet)                         |
|---------------------------|------------------------------------------------------|-------------------------------------------|
| `feedback_terse_zh`       | conversation style                                   | report style ✅                           |
| `feedback_workflow_split` | knows own role (don't execute)                       | knows own role (execute fully)            |
| `feedback_model_split`    | knows other side is literal → write detailed prompts | knows self is literal → don't 2nd-guess   |
| `env_paths`               | reference correct venv when writing prompt           | use correct venv when running ✅          |
| `project_<name>`          | full project context                                 | not strictly needed                       |
| `project_current_handoff` | knows progress → writes next prompt                  | not needed                                |

**Bottom line**: executor minimum = `feedback_terse_zh` + `feedback_model_split` + `env_paths`. Planner reads everything. Both sessions auto-load the same memory dir; what matters is which entries each role acts on.

---

## Inbox vs memory — complementary, not redundant

`docs/prompts/_inbox.md` and the memory directory serve different purposes.

- **Inbox** = "this task". One prompt, one execution, then archived. Short-lived.
- **Memory** = permanent style, environment paths, and role rules. Loaded on every session. Long-lived.

Both are needed. Inbox tells Sonnet what to do right now. Memory tells Sonnet how to behave and where the tools are. A good prompt in `_inbox.md` says "run pytest at `~/venvs/hello-world-venv/bin/pytest`" — it can say that confidently because `env_paths.md` in memory already established that path.

---

## What bootstrap.sh ships

When you run `bash bootstrap.sh <project>`, these five files are copied into the memory directory:

| File                          | Type     | Purpose                                                        |
|-------------------------------|----------|----------------------------------------------------------------|
| `MEMORY.md`                   | index    | One-line pointer per memory file; auto-loaded index           |
| `feedback_terse_zh.md`        | feedback | Terse 繁中 replies; mid-task pings = status, not stop          |
| `feedback_workflow_split.md`  | feedback | Planning window plans; execution window executes              |
| `feedback_model_split.md`     | feedback | Opus plans + writes detailed prompts; Sonnet executes literally |
| `env_paths.md`                | reference| Venv path, repo path, macOS iCloud trap warning               |

These templates have placeholder values. After bootstrap, localize manually:

- `env_paths.md` — fill in your actual venv path and repo path
- `MEMORY.md` — the index already points to all four files; add new entries here as you create them

---

## Adding a new memory

1. Write a file in the memory directory with the frontmatter format above. Choose a descriptive filename: `project_phase3_handoff.md`, `feedback_no_inline_comments.md`, etc.

2. Add a one-line pointer to `MEMORY.md`:
   ```
   - [phase 3 handoff](project_phase3_handoff.md) — current state after Phase 3 ship; next = Phase 4 auth
   ```

Keep `MEMORY.md` index lines under ~150 characters each. Lines after 200 in `MEMORY.md` are truncated by the auto-load mechanism — keep the index concise and move detail into the individual files.

---

## When to update / remove

Memory rots. A project entry that was accurate on 2026-04-21 may be wrong by 2026-05-01. A feedback entry based on a tool version that has since changed may now give bad guidance.

Rules:
- If reality changed, update or delete the memory entry rather than acting on stale info.
- If a memory conflicts with what you observe in the code or shell, trust what you observe — then fix the memory.
- `project_*` entries should be updated or archived after every phase ship.
- `reference_*` entries should be verified before recommending them to someone.

Do not accumulate stale memories "just in case." A wrong memory is worse than no memory.

---

## Auto-briefing on session start

After Phase 4b, bootstrapped projects include a SessionStart hook in `.claude/settings.json` that automatically prints `RESUME.md` (first 30 lines) and the last 5 commits every time you open a new Claude Code session:

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

For an on-demand briefing (without opening a new session), type `/brief` in any Claude Code session. It synthesizes `RESUME.md`, recent commits, and the latest `project_current_handoff` memory into a 5-8 line bullet summary.

See `.claude/commands/brief.md` for the full command spec.
