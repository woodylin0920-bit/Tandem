# Upgrading existing projects

`bash bootstrap.sh --upgrade-existing <path>` reverse-syncs the latest
Tandem framework into a project that was bootstrapped from an older
version. Defaults to **dry-run**; pass `--apply` to actually write changes.

## Usage

```bash
# See what would change
bash ~/Tandem/bootstrap.sh --upgrade-existing /path/to/target

# Actually write
bash ~/Tandem/bootstrap.sh --upgrade-existing /path/to/target --apply
```

## What gets touched

| Class | Behavior | Files |
|---|---|---|
| 🟢 **OVERWRITE** | Replaced with framework version (diff stats shown in dry-run) | `.claude/commands/{inbox,resume,sync,codex-audit,phase-gate}.md`<br>`scripts/{archive-prompts,memory,statusline,session-briefing,notify-blocked}.sh` |
| 🟡 **MERGE** | jq union: framework adds permissions/hooks; target wins on `statusLine` | `.claude/settings.json` |
| 🟠 **SKIP-if-modified** | Hash compare: pristine → overwrite; user-modified → skip + diff hint | `docs/prompts/README.md` |
| 🔴 **NEVER** | Untouched | `CLAUDE.md`, `RESUME.md`, `.gitignore`, `docs/prompts/_inbox.md`, memory dir |

## Pre-flight checks

1. Target path must exist
2. Target must be a git repo (`.git/` present) — abort otherwise; run `git init` first
3. Target must look like a Tandem project (`.claude/commands/inbox.md` exists)
4. Working tree dirty → warn but continue (so you can review the upgrade as a single commit). If you'd rather not mix existing changes with upgrade output, run `git stash` first or commit before upgrading.

## Sample dry-run output

```
[upgrade] Target: /path/to/target
[upgrade] Framework: /Users/you/Tandem

Would overwrite (3):
  .claude/commands/sync.md                     [new file]
  scripts/notify-blocked.sh                    [new file]
  scripts/statusline.sh                        [diff: +12 -3]

Would merge .claude/settings.json:
  + permissions.allow new entries:
      Bash(bash scripts/notify-blocked.sh:*)
      Bash(say:*)
  = statusLine kept (target's wins)

Skipped — user-modified (1):
  docs/prompts/README.md
    → diff: diff /path/to/target/docs/prompts/README.md /Users/you/Tandem/templates/prompts/README.md

Up-to-date (8):
  .claude/commands/inbox.md
  .claude/commands/brief.md
  ...

Run with --apply to actually write changes.
```

## After applying

Inspect changes before committing:

```bash
git -C /path/to/target diff
git -C /path/to/target add -A
git -C /path/to/target commit -m "chore: upgrade Tandem framework"
```

## When to upgrade

- New slash commands shipped (`/sync`, `/brief`, etc.)
- Hook config changed (e.g., new `Notification` hook for blocked-executor alerts)
- Statusline / session-briefing scripts updated
- Memory templates added (manual: copy from `templates/memory/` if you want them)

## What `--upgrade-existing` does NOT do

- **Doesn't touch your `CLAUDE.md`** — your project context is yours.
- **Doesn't add new memory files** — memory is per-project; copy manually if you want new starter memories.
- **Doesn't downgrade** — there's no rollback. Commit before running `--apply` so `git revert` is your escape hatch.
- **Doesn't migrate `_inbox.md`** — if you have a queued prompt, it stays exactly as-is.
