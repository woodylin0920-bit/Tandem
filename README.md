# woody-harness

Solo developer framework for fast-shipping AI-augmented projects with Claude Code (Opus + Sonnet split).

Extracted from real-world omni-sense development (2026-04-21 → 2026-04-27): 4 ship-able phases + safety audit in 1 week.

## What you get

- **Plan / Execute session split** — Opus terminal plans + writes prompts, Sonnet executes via `/inbox` slash command
- **Inbox handoff** — `docs/prompts/_inbox.md` is the cross-session mailbox
- **Memory system** — auto-loaded preferences, workflow rules, project state
- **Phase-based atomic commits** — every change ship-ready, revertable
- **Pre-flight checks** — every executor prompt starts with environment verification

## Quick start

```bash
# Clone harness once
git clone https://github.com/woodylin0920-bit/woody-harness ~/woody-harness

# Bootstrap new project
cd ~/Desktop/repo
bash ~/woody-harness/bootstrap.sh my-new-project
cd my-new-project

# Open two Claude Code sessions:
# Terminal 1 (planning):  claude  # Opus
# Terminal 2 (executor):  claude --model sonnet  # Sonnet, /effort medium
```

## Roadmap

- [x] Phase 1: bootstrap + inbox + memory templates (this commit)
- [ ] Phase 2: codex audit + safety audit + smoke test templates
- [ ] Phase 3: CI / hooks / push notifications
- [ ] Phase 4: philosophy docs + example project + user research framework

## Lineage

Born from [omni-sense](https://github.com/woodylin0920-bit/omni-sense), a fully-offline blind-navigation pipeline shipped solo in a week.

## License

MIT (see LICENSE).
