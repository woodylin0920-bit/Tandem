# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- `examples/hello-cli/` — static snapshot demo with WALKTHROUGH narrating the plan/execute loop on a one-feature project (Phase 4c).
- `docs/TUTORIAL.md`, `docs/HARNESS_ETHOS.md`, `docs/TROUBLESHOOTING.md`, `docs/MEMORY_SYSTEM.md`, `CONTRIBUTING.md` (Phase 4b).
- `.claude/commands/resume.md` slash command + `.claude/settings.json` SessionStart hook + bootstrap copies all commands (Phase 4b).
- `LICENSE` (MIT), `CHANGELOG.md`, `.github/ISSUE_TEMPLATE/{bug,feature}.md` + `config.yml`, README rewrite, `docs/prompts/` self-hosting (Phase 4a).

### Changed
- Generalized origin-project attributions across docs and templates — lessons preserved, framework now stands on its own without referencing a single source project (Phase 4c).

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
