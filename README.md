# Tandem

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg) ![Latest release](https://img.shields.io/github/v/release/woodylin0920-bit/Tandem) ![Bash + Markdown](https://img.shields.io/badge/stack-bash%20%2B%20markdown-blue) ![Zero deps](https://img.shields.io/badge/deps-zero-brightgreen)

> Two terminals, one bike: a planner session writes prompts, an executor session ships them. That's the whole metaphor — past this line, it's just a workflow framework.

A workflow framework I built for myself to ship faster with AI-assisted development. Self-use first, fork-friendly, but **not aimed at general adoption**.

If your habits look like mine — Claude Code (or any model with a markdown-aware prompt loop), two terminal sessions, git-native commits, comfort with bash and `_inbox.md`-style handoffs — this might fit. If not, this is probably the wrong tool. I'm not trying to convince you.

## Who this is for

- Solo engineers who already run AI-assisted dev and want it scaffolded
- Comfort with: git / bash / atomic commits / phase gates
- **Not for**: people looking for an IDE, a code generator, a deploy tool, team collaboration features, or a GUI

## What you get

- **Plan / Execute session split** — planner session writes prompts, executor session ships them via `/inbox` slash command. Markdown-based interface — works with Claude Code today, portable to any model that can read text prompts and produce file edits.
- **Inbox handoff** — `docs/prompts/_inbox.md` is the cross-session mailbox; archived per round with `## Result` block convention
- **Memory system** — auto-loaded preferences, workflow rules, and project state in `~/.claude-work/projects/<slug>/memory/`
- **Cross-project shared memory** — your preferences, workflow rules, and lessons-learned live once at `~/.claude-work/_shared/memory/` and symlink into every project. Add a memory once, get it everywhere. See [docs/SHARED_MEMORY.md](docs/SHARED_MEMORY.md).
- **Slash commands** — `/inbox`, `/sync`, `/brief`, `/codex-audit`, `/phase-gate` (see [docs/REFERENCE.md](docs/REFERENCE.md))
- **Status line** — terminal-bottom live indicator: `📥 inbox state · last commit · last result emoji`
- **Hooks** — `SessionStart` auto-briefing (RESUME + commits + latest archive Result), `Notification` alert when executor stalls (Funk + osascript banner)
- **Phase-based atomic commits** — every change ship-ready, revertable
- **Pre-flight checks** — every executor prompt starts with environment verification + final `## Result` block PASS/FAIL
- **Project lifecycle** — `bash bootstrap.sh --upgrade-existing <path>` syncs framework upgrades into older projects (dry-run by default); `--remove <path>` cleanly extracts the framework while preserving your work + memory (see [docs/UPGRADE.md](docs/UPGRADE.md), [docs/REMOVE.md](docs/REMOVE.md))
- **Memory portability** — `bash scripts/memory.sh export/import` to move memory dirs across machines

## Why Tandem

- **vs. raw Claude Code (or any model)**: gives you the prompt-handoff + memory + phase-gate scaffolding instead of starting blank every session. Interface is markdown, so swap models without rewiring.
- **vs. taskmaster / agent frameworks**: pure bash + markdown, zero deps, one-command bootstrap. Fork-friendly because there's nothing to fork *into* — it's just files.
- **vs. writing your own**: extracted from a real shipped solo project (see [ATTRIBUTION.md](ATTRIBUTION.md)).
- **The differentiator — cross-project self-improving memory**: your AI's understanding of you (preferences, workflow rules, lessons learned) lives once at `~/.claude-work/_shared/memory/` and follows you into every project. Add a memory once, get it everywhere. The longer you use Tandem, the less you re-explain. See [docs/SHARED_MEMORY.md](docs/SHARED_MEMORY.md).

## Quick start

```bash
git clone https://github.com/woodylin0920-bit/Tandem ~/Tandem
cd ~/Desktop/repo
bash ~/Tandem/bootstrap.sh my-new-project
cd my-new-project
```

Open two AI sessions (example uses Claude Code — substitute your model):

```bash
# Terminal 1 (planning):  claude  # Opus, /effort high
# Terminal 2 (executor):  claude --model sonnet  # Sonnet, /effort medium
```

Then `/inbox` in the executor session whenever the planner writes a prompt.

## Maintenance

- **Upgrade existing projects** — `bash bootstrap.sh --upgrade-existing <path>` reverse-syncs the latest framework into older projects. Dry-run by default. See [docs/UPGRADE.md](docs/UPGRADE.md).
- **Remove Tandem** — `bash bootstrap.sh --remove <path>` cleanly extracts the framework while preserving your own work + memory. Dry-run by default. See [docs/REMOVE.md](docs/REMOVE.md).

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
- [x] **T-1a** — cross-project shared memory layer (full: α infra + β promote tool + real promotion of 12 feedback to shared)
- [x] **S-1** — bootstrap upgrade/remove modes
- [x] **Phase 0** — rename to Tandem
- [ ] **Phase A** (in progress) — narrative refactor for model-agnostic positioning
- [ ] **Phase B** — model + effort recommendation system (was 4e)
- [ ] **Phase C** — learning loop (`/lessons` slash)
- ~~Phase 3: CI / hooks / push notifications~~ (deferred — see [docs/FUTURE.md](docs/FUTURE.md))

## Contributing

If you fork and your adaptation generalizes, PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md). I won't promise fast turnaround — this is a self-use tool, contributions get reviewed when I'm working on Tandem itself.

## License

MIT (see LICENSE).
