# woody-harness

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg) ![Latest release](https://img.shields.io/github/v/release/woodylin0920-bit/woody-harness) ![Bash + Markdown](https://img.shields.io/badge/stack-bash%20%2B%20markdown-blue) ![Zero deps](https://img.shields.io/badge/deps-zero-brightgreen)

Solo developer framework for fast-shipping AI-augmented projects with Claude Code (Opus + Sonnet split).

Extracted from real-world solo project development: 4 ship-able phases + safety audit in 1 week.

## What you get

- **Plan / Execute session split** — Opus terminal plans + writes prompts, Sonnet executes via `/inbox` slash command
- **Inbox handoff** — `docs/prompts/_inbox.md` is the cross-session mailbox; archived per round with `## Result` block convention
- **Memory system** — auto-loaded preferences, workflow rules, project state in `~/.claude-work/projects/<slug>/memory/`
- **Slash commands** — `/inbox`, `/sync`, `/brief`, `/codex-audit`, `/phase-gate` (see [docs/REFERENCE.md](docs/REFERENCE.md))
- **Status line** — terminal-bottom live indicator: `📥 inbox state · last commit · last result emoji`
- **Hooks** — `SessionStart` auto-briefing (RESUME + commits + latest archive Result), `Notification` alert when executor stalls (Funk + osascript banner)
- **Phase-based atomic commits** — every change ship-ready, revertable
- **Pre-flight checks** — every executor prompt starts with environment verification + final `## Result` block PASS/FAIL
- **Project lifecycle** — `bash bootstrap.sh --upgrade-existing <path>` syncs framework upgrades into older projects (dry-run by default); `--remove <path>` cleanly extracts the framework while preserving your work + memory (see [docs/UPGRADE.md](docs/UPGRADE.md), [docs/REMOVE.md](docs/REMOVE.md))
- **Memory portability** — `bash scripts/memory.sh export/import` to move memory dirs across machines

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

## Maintenance

- **Upgrade existing projects** — `bash bootstrap.sh --upgrade-existing <path>` reverse-syncs the latest framework into older projects. Dry-run by default. See [docs/UPGRADE.md](docs/UPGRADE.md).
- **Remove woody-harness** — `bash bootstrap.sh --remove <path>` cleanly extracts the framework while preserving your own work + memory. Dry-run by default. See [docs/REMOVE.md](docs/REMOVE.md).

**Quick reference**: see [`docs/REFERENCE.md`](docs/REFERENCE.md) for every command, script, and hook.

## See it in action

[`examples/hello-cli/`](examples/hello-cli/) is a static snapshot of a real
bootstrapped project after one phase shipped. Browse the files + read
`WALKTHROUGH.md` to see the plan/execute cycle on a concrete artifact.

## Roadmap

- [x] **Phase 1** — bootstrap + inbox + memory templates
- [x] **Phase 2** — codex audit + safety audit + smoke test templates
- [x] **Phase 4** — onboarding (TUTORIAL, HARNESS_ETHOS, TROUBLESHOOTING, MEMORY_SYSTEM, CONTRIBUTING) + `examples/hello-cli/` + feedback loop (statusline, /sync, /brief, notify-blocked) + lifecycle (bootstrap upgrade/remove via S-1)
- [x] **v0.4.1 release** — polish r2-r5 + S-1 (bootstrap modes) + retro
- [ ] **T-1a** — cross-project shared memory layer (next major; "Claude gets smarter as you work across projects")
- [ ] **4e** — model + effort recommendation system (`MODEL_GUIDE.md` + `/recommend`)
- ~~Phase 3: CI / hooks / push notifications~~ (deferred — see [docs/FUTURE.md](docs/FUTURE.md))

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines (issue templates, commit message conventions, how rounds get scoped).

## License

MIT (see LICENSE).
