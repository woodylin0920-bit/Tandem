# woody-harness reference

Flat list of every CLI mode, slash command, script, hook, and memory location. For *why* and *how to use*, see TUTORIAL / WORKFLOW / individual docs.

## bootstrap.sh modes

| Mode | Command | Detail |
|---|---|---|
| New project | `bash bootstrap.sh <name>` | Creates `<name>/` from templates, git init, copies framework files |
| Upgrade existing | `bash bootstrap.sh --upgrade-existing <path>` | Dry-run by default — see `docs/UPGRADE.md` |
| Upgrade apply | `bash bootstrap.sh --upgrade-existing <path> --apply` | Actually writes |
| Remove | `bash bootstrap.sh --remove <path>` | Dry-run by default — see `docs/REMOVE.md` |
| Remove apply | `bash bootstrap.sh --remove <path> --apply` | Actually deletes (memory preserved) |

## Slash commands (`.claude/commands/`)

| Command | Purpose |
|---|---|
| `/inbox` | Run `docs/prompts/_inbox.md`, append Result block, archive, notify (Glass on success, Mei-Jia "卡住了" on fail) |
| `/resume` | Print RESUME.md head + recent commits + handoff memory |
| `/sync` | Print git log + inbox state + latest archive Result block |
| `/codex-audit` | Run codex review per `docs/CODEX_AUDIT.md` template |
| `/phase-gate` | Run pytest + benchmark + emit verdict |

## Scripts (`scripts/`)

| Script | Usage | Purpose |
|---|---|---|
| `statusline.sh` | (auto via `.claude/settings.json` `statusLine`) | One-line status: 📥 inbox state · last commit · last result |
| `session-briefing.sh` | (auto via SessionStart hook) | Print RESUME head + commits + latest archive Result on session open |
| `notify-blocked.sh` | (auto via Notification hook) | Funk sound + osascript banner when executor blocked |
| `archive-prompts.sh` | `bash scripts/archive-prompts.sh` | Move _inbox.md content to `docs/prompts/<phase>.md`, append Result, clear inbox |
| `memory.sh` | `bash scripts/memory.sh export <out.tar.gz>` | Tar memory dir for transport |
| | `bash scripts/memory.sh import <in.tar.gz>` | Untar to memory dir |
| | `bash scripts/memory.sh list` | List memory files |
| `test-bootstrap.sh` | `bash scripts/test-bootstrap.sh` | 32-check regression test on bootstrap output |
| `smoke.sh` | `bash scripts/smoke.sh` | Real-machine smoke test runner (per docs/SMOKE_TESTING.md) |

## Hooks (`.claude/settings.json`)

| Event | Command | Effect |
|---|---|---|
| `SessionStart` | `bash scripts/session-briefing.sh` | Auto-prints briefing on session open |
| `Notification` | `bash scripts/notify-blocked.sh` | Auto-fires when executor stalled (permission prompt / idle) |

## Status line

Set in `.claude/settings.json` `statusLine.command = "bash scripts/statusline.sh"`. Renders at terminal bottom.

## Memory dir

`~/.claude-work/projects/<slug>/memory/`

- `<slug>` = absolute target path with `/` replaced by `-`
- `MEMORY.md` = index (always loaded into context)
- Individual memory files: `<type>_<topic>.md` (types: user / feedback / project / reference)

## Conventions

- **Inbox**: one slot at `docs/prompts/_inbox.md` — frozen once shipped to executor
- **Result block**: appended after `## Result` heading by `/inbox` on completion
- **Archive**: `docs/prompts/<date>-<phase>.md` after completion (via archive-prompts.sh)
- **Auto-queue**: sequence-bounded — executor must STOP after declared rounds, no auto-chain unless user pre-approves

## Source layout

```
woody-harness/
├── bootstrap.sh                  # entrypoint (new / upgrade / remove)
├── RESUME.md                     # self-host status (this harness on itself)
├── README.md                     # GitHub landing
├── CHANGELOG.md                  # version history
├── .claude/
│   ├── settings.json             # statusLine + hooks + permissions
│   └── commands/                 # slash commands
├── scripts/                      # all bash scripts (also copied to bootstrapped projects)
├── templates/                    # what bootstrap copies into new projects
│   ├── CLAUDE.md, RESUME.md, .gitignore
│   ├── prompts/                  # _inbox + framework templates (CODEX_AUDIT, SAFETY_AUDIT, ISSUES, README)
│   └── memory/                   # seed memory files
├── docs/                         # this docs/ tree
│   ├── REFERENCE.md              # this file
│   ├── TUTORIAL.md, WORKFLOW.md, HARNESS_ETHOS.md, ...
│   └── prompts/
│       ├── _inbox.md             # active inbox (this self-hosting harness)
│       └── <date>-<phase>.md     # archived rounds
└── examples/hello-cli/           # demo bootstrap output
```
