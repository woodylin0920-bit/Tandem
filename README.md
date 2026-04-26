# woody-harness

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg) ![Bash + Markdown](https://img.shields.io/badge/stack-bash%20%2B%20markdown-blue) ![Zero deps](https://img.shields.io/badge/deps-zero-brightgreen)

Solo developer framework for fast-shipping AI-augmented projects with Claude Code (Opus + Sonnet split).

Extracted from real-world solo project development: 4 ship-able phases + safety audit in 1 week.

## What you get

- **Plan / Execute session split** — Opus terminal plans + writes prompts, Sonnet executes via `/inbox` slash command
- **Inbox handoff** — `docs/prompts/_inbox.md` is the cross-session mailbox
- **Memory system** — auto-loaded preferences, workflow rules, project state
- **Phase-based atomic commits** — every change ship-ready, revertable
- **Pre-flight checks** — every executor prompt starts with environment verification

## Why woody-harness?

- **vs. raw Claude Code**: gives you the prompt-handoff + memory + phase-gate scaffolding instead of starting blank every session
- **vs. taskmaster / agent frameworks**: pure bash + markdown, zero deps, one-command bootstrap, fork-friendly
- **vs. writing your own**: extracted from real shipped projects, not a theoretical framework

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

## See it in action

[`examples/hello-cli/`](examples/hello-cli/) is a static snapshot of a real
bootstrapped project after one phase shipped. Browse the files + read
`WALKTHROUGH.md` to see the plan/execute cycle on a concrete artifact.

## Roadmap

- [x] Phase 1: bootstrap + inbox + memory templates
- [x] Phase 2: codex audit + safety audit + smoke test templates
- ~~Phase 3: CI / hooks / push notifications~~ (deferred — see FUTURE.md)
- [ ] Phase 4: philosophy docs + example project + user research framework

## License

MIT (see LICENSE).
