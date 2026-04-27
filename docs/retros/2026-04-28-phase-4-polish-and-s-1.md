# Retro: Phase 4 polish r2-r5 + S-1 (2026-04-28)

**Span**: v0.4.0 (commit `7f55a78`) → v0.4.1 (commit `cc7a5cc`)
**Commits**: 11 non-archive (15 incl. archive)
**Output**: 4 polish rounds + 1 self-use feature → CHANGELOG entries above

## What shipped, by round

### polish-r2 — memory portability + regression safety
- `scripts/memory.sh` (export / import / list) — memory dir tar/untar for cross-machine moves
- `scripts/test-bootstrap.sh` — 32-check regression test on `bash bootstrap.sh` output
- **Why**: portability is one of two top user-stated weights (alongside upgrade); bootstrap had no automated check before — every change was hand-tested

### polish-r3 — visibility (statusline + /sync)
- `scripts/statusline.sh` (~48ms) wired into `.claude/settings.json` `statusLine` — `📥 inbox · last commit · last result emoji` always visible
- `.claude/commands/sync.md` slash command — `git log` + inbox state + latest archive Result
- `scripts/session-briefing.sh` extended to tail latest archive Result on session start
- **Why**: polling pain. User had to keep asking "現在呢" — now state is glanceable, briefing auto-fires on session open

### polish-r4 — failure feedback (notify-blocked + empty inbox)
- `scripts/notify-blocked.sh` + Notification hook — Funk + osascript when executor stalls
- `templates/prompts/_inbox.md` truly empty (1 byte) so fresh bootstrap statusline shows `📥 empty`
- **Why**: silent stalls. User would walk away from a `/inbox` and not realize executor was blocked on a permission prompt 10 minutes ago

### S-1 — bootstrap lifecycle (upgrade + remove)
- `bash bootstrap.sh --upgrade-existing <path> [--apply]` with 4-tier file classification (overwrite / jq-merge / skip-if-modified / never)
- `bash bootstrap.sh --remove <path> [--apply]` with reverse jq merge for settings.json + memory dir always preserved
- `docs/UPGRADE.md`, `docs/REMOVE.md`
- **Why**: existing self-use projects couldn't pick up framework upgrades without manual file copying or full re-bootstrap (which would clobber customizations)

### polish-r5 — self-host gaps (RESUME + REFERENCE + briefing fallback)
- `RESUME.md` at root (was missing — woody-harness was bootstrapping others but not itself)
- `docs/REFERENCE.md` flat cheatsheet (every CLI mode / slash command / script / hook in one page)
- `scripts/session-briefing.sh` falls back when `RESUME.md` absent
- **Why**: dogfooding gaps surfaced in conversation — user kept asking "我怎麼知道所有指令", noticed SessionStart was silent on woody-harness root

## What worked

1. **Sequence-bounded auto-queue rule**: when user pre-approved a 3-commit sequence, executor would chain — but rule explicitly capped at the sequence boundary. Caught misfires before they happened.
2. **`## Result` block + archive convention**: every shipped round has a verifiable PASS/FAIL list; debug starts with `tail` on the latest archive, no guessing.
3. **Planner / executor split via two terminals (Opus + Sonnet)**: explicit prompts forced design discipline; Sonnet's literal execution caught spec ambiguity that would have rotted in a single-model session.
4. **macOS `osascript` notification + `afplay Glass.aiff`**: turning round completion into an audible signal eliminated polling entirely.

## What surprised / what we learned

1. **Self-host gaps are invisible until you ask "what do I do daily"**: RESUME.md and REFERENCE.md only became obvious after user asked unrelated UX questions — would have shipped v0.4.0 without them.
2. **Discovery > completeness**: REFERENCE.md adds zero new functionality but was the highest-leverage doc this release because user couldn't navigate the surface area.
3. **dry-run-by-default is non-negotiable**: both upgrade and remove modes default to dry-run; `--apply` is a separate gesture. This kills "I didn't mean to" failure modes.
4. **`jq` symmetric merge is harder than it looks**: reverse-merge for `--remove` needed unique_by on hook command strings + cascaded null-cleanup for empty arrays/keys. Spec'd in S-1 prompt before any code, spec held — Sonnet didn't need to redesign mid-implementation.

## What's still gnarly

1. **No team mode**: `T-1` (memory shared/private split) + `Team-gap-2` (convention pre-commit hook) deferred to last per user priority — fine for now (self-use first), but `~/.claude-work/projects/<slug>/memory/` is currently single-user by design.
2. **No `MODEL_GUIDE` / `/recommend`**: `4e` round queued but not yet designed — heuristic (`task type → model + effort`) lives in user's head, not the framework. Hardcoded "Opus plans, Sonnet executes" works for now.
3. **No release CI**: tags are pushed by hand. Acceptable for self-use, but if external adoption ever picks up, this'll need automation.
4. **Auto-queue authorization is conventions-only**: relies on planner discipline to honor "STOP after declared rounds" — no guardrail in code.

## Stats

- **v0.4.0 → v0.4.1**: ~12 hours of planning+execution (2026-04-27 evening → 2026-04-28 evening)
- **Commits**: 15 (11 substantive + 4 archive housekeeping)
- **New files**: ~14 (scripts × 5, slash commands × 1, docs × 5, RESUME, examples 0)
- **Net LOC delta**: ~unknown; mostly docs + bash; zero tests because the harness is shell-only and `test-bootstrap.sh` is the regression suite

## Next

Per priority memory `project_priority_team_last`:
1. **4e** — MODEL_GUIDE + `/recommend` slash + Execution profile convention (design discussion needed first)
2. **T-1** — memory shared/private split (team prep, deferred to last)
3. **Team-gap-2** — convention pre-commit hook (paired with T-1)

Or: pause feature work and dogfood v0.4.1 on a real existing project via `--upgrade-existing` to surface the next gap.
