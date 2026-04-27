# woody-harness — RESUME

**What**: Self-use solo-dev workflow harness for Claude Code (planner/executor split via 2 terminals).
**Version**: 0.4.0 + S-1 (bootstrap --upgrade-existing / --remove modes shipped 2026-04-27)
**Repo**: https://github.com/woodylin0920-bit/woody-harness

## Current focus

Phase 4 polish + self-host gaps. Recent rounds: r1 (TROUBLESHOOTING), r2 (memory.sh + test-bootstrap), r3 (statusline + /sync), r4 (notify-blocked + empty inbox), r5 (RESUME + REFERENCE + briefing fallback).

## How to use this harness on itself

woody-harness self-hosts since 4a — its own inbox lives at `docs/prompts/_inbox.md`, runs through `/inbox` slash command, archives via `scripts/archive-prompts.sh`.

```bash
# Planner terminal (Opus):
claude
# discuss design, write prompt to docs/prompts/_inbox.md

# Executor terminal (Sonnet):
claude --model sonnet
/inbox    # runs the queued prompt, commits, archives, notifies
```

## Where to look

| Topic | File |
|---|---|
| Tutorial / first-time setup | `docs/TUTORIAL.md` |
| Flat command/script/hook reference | `docs/REFERENCE.md` |
| Workflow rationale (planner/executor split) | `docs/WORKFLOW.md` |
| Design principles | `docs/HARNESS_ETHOS.md` |
| Memory system | `docs/MEMORY_SYSTEM.md` |
| bootstrap upgrade mode | `docs/UPGRADE.md` |
| bootstrap remove mode | `docs/REMOVE.md` |
| Troubleshooting | `docs/TROUBLESHOOTING.md` |
| Deferred ideas | `docs/FUTURE.md` |
| Phase gates / smoke testing | `docs/PHASE_GATING.md`, `docs/SMOKE_TESTING.md` |
| Codex audit format | `docs/CODEX_AUDIT.md` |

## Memory dir

`~/.claude-work/projects/-Users-woody-Desktop-repo-public-woody-harness/memory/`

`MEMORY.md` is the index; individual memory files (user/feedback/project/reference) live alongside.

## Active inbox

See `docs/prompts/_inbox.md` for any currently queued task. Empty = no work in flight. Run `bash scripts/statusline.sh` for one-line state.

## Recent shipped phases

- **Phase 1 (2026-04-27)**: bootstrap + inbox + memory templates + WORKFLOW
- **Phase 2 (2026-04-27)**: codex/safety audit + smoke + phase-gate
- **Phase 4a (2026-04-28)**: legal/entry — LICENSE, CHANGELOG, README rewrite, ISSUE_TEMPLATE×3, self-host inbox
- **Phase 4b (2026-04-28)**: onboarding — TUTORIAL, HARNESS_ETHOS, TROUBLESHOOTING, CONTRIBUTING, MEMORY_SYSTEM, /brief slash (originally /resume), SessionStart hook
- **Phase 4c (2026-04-28)**: examples/hello-cli/ + omni-sense purge
- **Phase 4d (2026-04-28)**: /inbox feedback loop (Result block + osascript notify)
- **Phase 4-polish r1-r4 (2026-04-28)**: archive helper / memory.sh / test-bootstrap / statusline / /sync / notify-blocked / empty-inbox fix
- **S-1 (2026-04-27)**: bootstrap.sh --upgrade-existing + --remove modes
- **Polish r5 (this round)**: RESUME self-host + REFERENCE + session-briefing fallback
