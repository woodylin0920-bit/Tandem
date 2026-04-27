# Contributing

## This is a personal framework — but PRs are welcome

Tandem was extracted from one person's workflow. The bias is toward solo engineers using AI-assisted dev tooling. That context shapes every design decision here.

PRs are welcome for:
- Bug fixes in `bootstrap.sh` or slash commands
- Clarifications in docs where something was confusing or wrong
- Improvements to slash commands that came from real friction
- Troubleshooting entries from gotchas you hit that aren't in `docs/TROUBLESHOOTING.md`

PRs are less welcome for:
- Expanding scope beyond "one engineer + their AI of choice"
- Adding dependencies (see below)
- Adding new languages or runtimes to the bootstrap

If you are unsure whether your contribution fits, open an issue first.

---

## Fork → adapt → upstream

Forking is the primary use case. The harness is designed to be forked, stripped down, and adapted to your project. That is not a workaround — it is the intended path.

If your adaptation turns out to generalize well (it works for multiple projects, not just yours), open a PR to upstream it. If it is project-specific (e.g., your venv path, your specific SLO numbers), keep it in your fork. Do not upstream project-specific details.

The rule of thumb: would a stranger who forks this repo benefit from your change? If yes, PR it. If no, keep it.

---

## Contribution areas

Changes are welcome in:

- **`templates/`** — CLAUDE.md, RESUME.md, memory templates, prompt templates
- **`docs/`** — any doc file
- **`.claude/commands/`** — slash command improvements or new slash commands
- **`bootstrap.sh`** — bug fixes, new files to copy, portability fixes
- **`scripts/`** — utility scripts that fit the zero-dep constraint

**Off-limits without a prior issue discussion:**

- **Dependency additions** — adding `npm`, `pip`, `cargo`, or any package manager dependency to the harness itself. Zero deps is a hard constraint. If you have a use case that requires a dependency, open an issue and explain it.
- **New language runtimes** — adding Python, Node, or other runtime requirements to bootstrap or core harness scripts.

---

## Commit convention

Subject only. No body. No co-author trailers.

Format: `type: short imperative summary`

Types:
- `feat` — new capability
- `fix` — bug fix
- `docs` — documentation change
- `chore` — maintenance (version bumps, test infra, cleanup)

Examples:
```
feat: add /smoke slash command for one-shot smoke runs
fix: bootstrap sed substitution fails on GNU Linux
docs: add TROUBLESHOOTING entry for iCloud venv slowdown
chore: remove stale FUTURE.md entry for CI hooks
```

Keep subject lines under 72 characters. Use imperative mood ("add", not "added" or "adds").

---

## PR checklist

Before opening a PR:

- [ ] Commits are atomic — one logical change per commit
- [ ] If you changed `bootstrap.sh` or any template: test with `bash bootstrap.sh /tmp/test-pr-bootstrap` and verify the output looks right
- [ ] No broken internal links in any `.md` file you touched
- [ ] No new dependencies added without a prior issue
- [ ] `CHANGELOG.md`'s `## [Unreleased]` section updated with a one-line summary of your change

---

## Issue first for big changes

If your change is larger than ~100 lines of new code, or touches multiple subsystems (e.g., bootstrap + a doc + a slash command), open an issue first. Describe what you want to change and why. This avoids the situation where you write a lot of code and the PR gets declined because the direction doesn't fit.

For small changes (typo fixes, single-file doc clarifications), go straight to a PR — no issue needed.

---

## Code of conduct

Be kind, assume good faith, contributions are welcome from anyone.
