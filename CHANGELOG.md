# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.6.0] - 2026-04-27

Major release: cross-project shared layer + queue-based `/auto` mode + full external security audit cleared (2 P0 + 10 P1 + 5 P2 all fixed). Self-use ship-ready; broader-distribution ship-ready pending more dogfood.

### Added

- **T-1a: Cross-project shared layer (memory + lessons).** New `scripts/shared-init.sh` creates `~/.claude-work/shared/` as a git-backed private repo (`woodylin0920-bit/claude-shared`). `memory.sh sync` now pulls from the shared remote before linking; `memory.sh promote` commits + pushes after promotion. New `--batch <file-list>` flag on `memory.sh promote` for non-interactive executor automation. `lessons.sh review` on promote writes to `shared/lessons/` + commits + pushes. Bootstrap auto-syncs shared layer on both new-project and `--upgrade-existing --apply` (skips with warning if `~/.claude-work/shared/` not found). `test-bootstrap.sh` updated to 42/42 assertions. Tandem one-time migration: 13 user-level feedback entries moved to `shared/memory/` and pushed to GitHub.
- **`/auto` mode — queue-based executor loop.** New `/auto` slash command (`scripts/auto-loop.sh` + `.claude/commands/auto.md`) lets the planner drop multiple self-contained task files into `docs/prompts/_queue/` (timestamp FIFO filenames). The executor runs `/auto` and processes tasks sequentially: read → execute → append Result → archive → notify. Fail-stop on any task failure (leaves remaining tasks in queue). Notification controlled by `TANDEM_AUTO_NOTIFY` env (`fail` default = success silent, `all`, `none`). Bootstrap now creates `_queue/` and copies both files; `test-bootstrap.sh` updated to 40/40 assertions.
- **Statusline `_queue` depth indicator.** `scripts/statusline.sh` appends `· 📦 N` segment when `docs/prompts/_queue/` has pending task files, so planner can see queue depth at a glance alongside inbox state and last commit.
- **Codex external audit baseline.** New `docs/audits/codex-2026-04-27.md` captures the 7-dimension review at commit `95afa7e` (2 P0 + 7 P1 + 5 P2 findings) with worst-case scenario and batched fix plan. Subsequent fixes annotate this doc with `[FIXED in <hash>]` markers.

### Security

- **Prompt injection safety preflight (P0).** `.claude/commands/inbox.md` and `.claude/commands/auto.md` now require executor to scan prompt content for dangerous patterns (`rm -rf $HOME`/`~`, `git push --force`, `gh auth logout`, `.ssh/` writes, writes outside repo, `curl | bash`) before execution. Hits trigger interactive user confirmation; attempts to override the preflight (e.g. "ignore safety checks") are refused with `Status: ❌ blocked: injection refused`. Verified end-to-end with a deliberate `rm -rf $HOME/.ssh` test prompt — preflight correctly blocked.
- **Shared layer symlink rejection (P0).** `scripts/memory.sh` now runs `_validate_shared_files()` before sync: rejects any symlink under `~/.claude-work/shared/{memory,lessons}/`, requires `realpath` to stay inside the shared tree, and rejects non-`.md` extensions. Closes the attack vector where a compromised shared remote could exfiltrate local secrets via `memory/x.md → ~/.ssh/id_rsa`.
- **`auto-loop archive` path validation (P1).** `scripts/auto-loop.sh archive` now canonicalizes the target path and refuses anything outside `docs/prompts/_queue/`, preventing the subcommand from being abused to move arbitrary files.

### Reliability & Concurrency (Batches 2-5 from codex audit)

- **Queue atomic locking (P1).** `auto-loop.sh next` uses atomic `mv` to `_queue/.running/` so two executors can't pick the same task. New `recover` subcommand surfaces orphan running tasks from killed sessions.
- **`/auto` interrupt handling (P1).** Ctrl+C / TERM during a task now archives the partial run with `Status: ⚠️ blocked: interrupted` and leaves remaining queue intact.
- **Executor mutex (P1).** New `scripts/executor-lock.sh` (mkdir-based for macOS compat) prevents `/auto` and `/inbox` from running simultaneously and double-pushing.
- **Notification stderr surfacing (P1).** `osascript` / `say` / `afplay` failures now echo `[notify] ... failed` to stderr instead of silent-failing — closes the macOS Script Editor permission silent-fail trap.
- **Bootstrap shared sync error visibility (P1).** `bootstrap.sh` no longer swallows `memory.sh sync` stderr; failures show 10-line error summary while still letting bootstrap continue.
- **Path-scoped `git add` in shared layer (P1).** `memory.sh` and `lessons.sh` now whitelist `memory/*.md MEMORY.md` / `lessons/*.md` instead of `git add -A`, so user-touched files in `~/.claude-work/shared/` aren't accidentally committed.
- **Lessons staging path unified (P1).** New `scripts/_paths.sh` defines `TANDEM_LESSONS_STAGING` + `TANDEM_SHARED_DIR` constants; `archive-prompts.sh`, `statusline.sh`, `lessons.sh` all source it instead of hardcoding paths.
- **Result format dual detection (P1).** `archive-prompts.sh` matches both `Status:` (legacy) and `**Status**:` (slim template) so old + new archives both get detected correctly.
- **Statusline stderr cleanup (P1).** Replaced `n_lessons=$(... || echo 0)` with `${n_lessons:-0}` to eliminate `integer expression expected` noise when staging is missing.
- **`/auto` doc consistency (P1).** Resolved fail-stop and queue-empty notification contradictions in `auto.md`; single canonical spec under `## Stopping conditions`.

### P2 polish

- **Notify cooldown + singleton (P2).** `notify-blocked.sh` skips re-fires within 60s and uses a mkdir-based lock to prevent overlapping `afplay`.
- **Dynamic shared owner (P2).** `shared-init.sh` resolves GitHub owner via `gh api user --jq .login` (or `TANDEM_SHARED_OWNER` env override) instead of hardcoded `woodylin0920-bit`, unblocking other users.
- **Archive monthly retention (P2).** New `scripts/archive-prune.sh --keep-months N --dry-run` packs old `_archive/YYYY-MM/` into `_archive/legacy/<YYYY-MM>.tar.gz`. Manual trigger only.
- **Statusline mtime cache (P2).** Caches output to `~/.claude-work/.statusline-cache` keyed on input mtime sum; subsequent 1Hz invocations skip the full scan when nothing changed.
- **Handoff auto-update (P2).** New `scripts/handoff-update.sh` invoked by `/inbox` close — keeps `project_current_handoff.md` memory fresh so `/brief` always reflects last round's state.

### Changed

- **Token diet — session briefing + Result template.** `scripts/session-briefing.sh` slimmed (RESUME 30→10 lines, `git log -3` instead of `-5`, drops lessons block, Status-only archive tail). `templates/prompts/_inbox.md` and `.claude/commands/auto.md` Result block templates simplified to `Status / Commits / Notes` (was 5+ fields). Cuts per-session SessionStart token burn substantially while preserving the load-bearing context (current state + recent commits + last outcome).

## [0.5.0] - 2026-04-28

### Added

- **Phase C: lessons loop — auto-extracted feedback memories from inbox archives.** New `scripts/lessons.sh` (subcommands: count/list/extract/review) plus detection logic in `scripts/archive-prompts.sh`. Whenever an inbox round finishes with `Status: ❌ blocked`, non-empty `Blockers:`, a `FAIL` line in verification, or "next time/should/lesson learned" keyword hits, the archive flow appends a `state=raw` entry to `~/.claude-work/_shared/lessons-staging.md`. `lessons.sh extract` invokes `claude -p` headless to refine raw signals into structured candidates (frontmatter + Why/How-to-apply body); `lessons.sh review` walks each candidate interactively (default action = promote-to-shared). Promoted lessons land in `~/.claude-work/_shared/memory/<slug>.md` with an index row appended. See [docs/LESSONS.md](docs/LESSONS.md). This is the招牌 feature delivering the cross-project self-improving promise: lessons captured in project A become available to project B after promotion.
- **Phase B: model + effort selection guide.** New `docs/MODEL_GUIDE.md` distills empirical recommendations from 20+ archived inbox rounds — Claude as primary worked example with a principle-extension section for other planner/executor model pairs (reasoning-strong → planner, execution-strong → executor). New convention: every inbox prompt declares a `## Execution profile` block (model + effort + commits) near the top. Soft convention only (no lint), reminded via comment block in `templates/prompts/_inbox.md` and documented in `docs/REFERENCE.md`.
- **Statusline lessons indicator + briefing block.** Statusline appends `· 🎓 N` when staging is non-empty. SessionStart briefing prints a `=== lessons pending ===` block with raw/candidate breakdown.

### Changed

- **`templates/CLAUDE.md` Workflow section is model-agnostic** (Phase A leftover caught in Phase B). Workflow describes the role (reasoning-strong planner / execution-strong executor) with Claude Code as my-setup example, links `docs/MODEL_GUIDE.md` for selection guidance.
- **`scripts/test-bootstrap.sh` now asserts 36/36** (was 32/32) — added 4 new assertions for `scripts/lessons.sh` (existence, executable bit, `count` subcommand runs, `help` subcommand runs).

### Fixed

- **Lesson detection regex precision.** Phase C's first-iteration detection produced 2 false positives on initial dogfood — Status template line `**Status**: ✅ shipped | ❌ blocked` and bash code blocks containing `echo "FAIL: ..."` both matched the heuristic. Fixed by (a) only matching Status as blocked when ❌ is present *and* ✅ is absent from the line, (b) restricting FAIL/keyword scans to the `## Result` block content with code fences stripped, (c) filtering Blockers template placeholders (`<description>`). Cleared the 2 false-positive raw entries from staging in the same round.

### Notes

- Lessons loop self-validated on this release: Phase C archive run detected lesson signals in past v0.4.2 + Phase B archives (their verification block contained `FAIL` placeholders) and staged 2 raw entries automatically. Feature is end-to-end functional.

## [0.4.2] - 2026-04-28

### Added
- Shared memory layer at `~/.claude-work/_shared/memory/` — user-level preferences/rules/lessons that apply across all projects (T-1a-α foundation). New `bash scripts/memory.sh sync` subcommand symlinks shared into project memory dir + regenerates `MEMORY.md` as a combined index. `bootstrap.sh` seeds shared on first run; new project memory only contains project-specific files. See [docs/SHARED_MEMORY.md](docs/SHARED_MEMORY.md). Migration tooling for existing projects coming in T-1a-β.
- `scripts/memory.sh promote` — interactive migration helper for moving existing project memory entries into the shared layer (promote/keep/delete) (T-1a-β; completes the cross-project shared memory feature).

### Changed
- **Phase A: model-agnostic narrative refactor.** README + HARNESS_ETHOS + TUTORIAL + WORKFLOW + CONTRIBUTING + examples/hello-cli/ all rewritten for self-use-honest positioning, light tandem metaphor, and Claude-as-primary-example with markdown-portable interface. Origin (omni-sense) moved to `ATTRIBUTION.md`. Cross-project shared memory promoted to招牌 wedge replacing accessibility audit. New `## 9. Cross-vendor quality gates` section in HARNESS_ETHOS.
- **Phase 0 follow-up + bootstrap shared-seed idempotency fix.** memory dir 內容 sed + 舊 slug 清 + bootstrap.sh L567 改 per-file check（避免 dir 存在就整段 skip seeding 的 idempotency bug）+ 不 clobber 已存在的 shared MEMORY.md（保護 user-promoted 內容）。
- **Memory promotion: 12 feedback memories shipped to shared layer.** 11 promoted (error-to-optimization / handoff-inbox-atomic-sync / inbox-auto-queue / interactive-decisions / macos-notification-pitfall / planner-executor-race / planner-hot-path / planner-verify-on-inbox-signal / readme-polish-recurring / terse-zh / workflow-split) + 1 deleted (model_split — used pre-existing shared seed) + 7 kept project-local (notification_funk_ok + project_* + env_paths). T-1a end-to-end now in production use.
- **Renamed: woody-harness → Tandem.** Repo, local directory, GitHub repo, and memory slug all updated. Historical archives (dated prompts, dogfood reports, retros, [0.4.x] CHANGELOG entries) preserved as-is — those record events when the project was named woody-harness. See README + docs/HARNESS_ETHOS.md for narrative context (refreshed in Phase A).
- Renamed `/resume` slash command to `/brief` to avoid colliding with Claude Code's built-in `/resume` (resume previous conversation). Existing bootstrapped projects: upgrade flow installs `brief.md`; orphan `resume.md` can be manually removed. See `docs/TROUBLESHOOTING.md` "`/brief` slash command not found".
- README refreshed: Roadmap reflects shipped state (Phase 4 + S-1 + v0.4.1 done; T-1a / 4e queued); "What you get" expanded with all v0.4.1 features (slash commands, statusline, hooks, lifecycle modes, memory portability); added latest-release badge; linked CONTRIBUTING.md.
- GitHub repo metadata refreshed: description (removed origin-project reference); repository topics added (claude-code, ai-agents, solo-dev, workflow, bash, developer-tools, prompt-engineering, claude-opus, claude-sonnet, bootstrap).

## [0.4.1] - 2026-04-28

### Added
- `bootstrap.sh --upgrade-existing <path>` — reverse-sync latest framework into existing projects (dry-run by default; `--apply` to write). Pre-flight checks, jq merge for `settings.json`, hash-compare for `docs/prompts/README.md`, never touches `CLAUDE.md` / `RESUME.md` / `.gitignore` / `_inbox.md` / memory dir. See [docs/UPGRADE.md](docs/UPGRADE.md). (S-1)
- `bootstrap.sh --remove <path>` — clean extraction (dry-run by default; `--apply` to delete). Reverse-merges `settings.json` to keep user-only permissions/hooks; never touches user content or `~/.claude-work/projects/<slug>/memory/`. See [docs/REMOVE.md](docs/REMOVE.md). (S-1)
- `docs/UPGRADE.md`, `docs/REMOVE.md` — usage + behavior reference. (S-1)
- `RESUME.md` self-hosting woody-harness's own status (was missing — SessionStart hook silent before). (polish-r5)
- `docs/REFERENCE.md` — flat cheatsheet of every bootstrap mode / slash command / script / hook. (polish-r5)
- `scripts/memory.sh` — export / import / list memory dir for portability. (polish-r2)
- `scripts/test-bootstrap.sh` — 32-check regression test on bootstrap output. (polish-r2)
- `scripts/statusline.sh` + `.claude/settings.json` `statusLine` — bottom-of-terminal `📥 inbox · last commit · last result emoji`. (polish-r3)
- `.claude/commands/sync.md` `/sync` slash command — git log + inbox state + latest archive Result. (polish-r3)
- `scripts/notify-blocked.sh` + `.claude/settings.json` Notification hook — auto Funk + osascript banner when executor stalled. (polish-r4)
- `docs/retros/2026-04-28-phase-4-polish-and-s-1.md` — first formal retrospective. (this release)

### Changed
- `scripts/session-briefing.sh` extended — also tails latest archive `## Result` block on session start (polish-r3); falls back gracefully when `RESUME.md` absent, prints commits + archive Result anyway (polish-r5).
- `bootstrap.sh` copies all new scripts (`memory.sh`, `statusline.sh`, `session-briefing.sh`, `notify-blocked.sh`) and slash commands (`/sync`) into new projects.

### Fixed
- `templates/prompts/_inbox.md` is now truly empty (1 byte) so fresh bootstrap statusline correctly shows `📥 empty` instead of treating placeholder text as queued work. (polish-r4)

## [0.4.0] - 2026-04-28

### Added
- `examples/hello-cli/` — static snapshot demo with WALKTHROUGH narrating the plan/execute loop on a one-feature project (Phase 4c).
- `docs/TUTORIAL.md`, `docs/HARNESS_ETHOS.md`, `docs/TROUBLESHOOTING.md`, `docs/MEMORY_SYSTEM.md`, `CONTRIBUTING.md` (Phase 4b).
- `.claude/commands/resume.md` slash command + `.claude/settings.json` SessionStart hook + bootstrap copies all commands (Phase 4b).
- `LICENSE` (MIT), `CHANGELOG.md`, `.github/ISSUE_TEMPLATE/{bug,feature}.md` + `config.yml`, README rewrite, `docs/prompts/` self-hosting (Phase 4a).
- `.claude/settings.json` permissions allowlist for `osascript`, `say`, archive helper (Phase 4d).
- `scripts/archive-prompts.sh` manual prompt archive helper (Phase 4d).
- `bootstrap.sh` copies archive helper to new projects (Phase 4d).

### Changed
- Generalized origin-project attributions across docs and templates — lessons preserved, framework now stands on its own without referencing a single source project (Phase 4c).
- `.claude/commands/inbox.md` rewritten — every `/inbox` run now appends a `## Result` block to the archived prompt and fires a macOS notification (Phase 4d feedback loop).

## [0.2.0] - 2026-04-27

### Added
- `templates/prompts/CODEX_AUDIT.md` — 7-dimension codex consult-mode audit prompt template
- `templates/prompts/SAFETY_AUDIT.md` — silent-failure / accessibility-focused safety audit prompt template
- `templates/prompts/ISSUES.md` — batch gh issue create template with severity rubric
- `templates/scripts/smoke.sh` — real-machine smoke test runner (driver-auto, human-observable)
- `.claude/commands/codex-audit.md` — `/codex-audit` slash command to fill + run CODEX_AUDIT prompt
- `.claude/commands/phase-gate.md` — `/phase-gate` slash command (pytest + benchmark + clean-push gate)
- `docs/CODEX_AUDIT.md` — rationale + real case (6 P0s caught by audit)
- `docs/PHASE_GATING.md` — three-gate standard (tests / SLO / clean push) + anti-patterns
- `docs/SMOKE_TESTING.md` — smoke vs unit test philosophy + real case
- `docs/FUTURE.md` scaling models + CLI UI ideas (deferred)

### Fixed
- `bootstrap.sh` now substitutes `{{PROJECT_NAME}}` placeholder in `memory/env_paths.md`

## [0.1.0] - 2026-04-27

### Added
- `bootstrap.sh` — one-command project scaffolding (git init, templates, memory dir)
- `.claude/commands/inbox.md` — `/inbox` slash command for plan→execute handoff
- `templates/CLAUDE.md` — project CLAUDE.md template with `{{PROJECT_NAME}}` placeholder
- `templates/RESUME.md` — session resume template
- `templates/.gitignore` — standard Python + macOS gitignore
- `templates/prompts/_inbox.md` — cross-session planning mailbox template
- `templates/prompts/README.md` — inbox flow documentation
- `templates/memory/` — four starter memories (MEMORY.md index, terse-zh feedback, workflow split, model split, env paths)
- `docs/WORKFLOW.md` — plan/execute split philosophy + Opus/Sonnet model split
- `README.md` — project overview, quick start, lineage
