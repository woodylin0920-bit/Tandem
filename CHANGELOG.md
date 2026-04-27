# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

(empty — next round adds entries)

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
