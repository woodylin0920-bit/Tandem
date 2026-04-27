# Removing woody-harness from a project

`bash bootstrap.sh --remove <path>` cleanly extracts the framework from a
project, leaving your own work untouched. Defaults to **dry-run**; pass
`--apply` to actually delete.

## Usage

```bash
# See what would be deleted
bash ~/woody-harness/bootstrap.sh --remove /path/to/target

# Actually delete
bash ~/woody-harness/bootstrap.sh --remove /path/to/target --apply
```

## What gets deleted

| Class | Behavior | Files |
|---|---|---|
| 🟢 **DELETE** | Removed unconditionally | `.claude/commands/{inbox,resume,sync,codex-audit,phase-gate}.md`<br>`scripts/{archive-prompts,memory,statusline,session-briefing,notify-blocked}.sh`<br>`docs/prompts/_inbox.md` |
| 🟡 **REVERSE-MERGE** | Framework permissions/hooks/statusLine stripped; user-only entries preserved; file removed entirely if it becomes `{}` | `.claude/settings.json` |
| 🟠 **DELETE-if-pristine** | Hash matches framework → delete; user-modified → skip + diff hint | `docs/prompts/README.md` |
| 🔴 **NEVER** | Untouched | `CLAUDE.md`, `RESUME.md`, `.gitignore`<br>`docs/prompts/_archive/` (your prompt history)<br>`~/.claude-work/projects/<slug>/memory/` (your memory) |

After deletion, empty dirs (`scripts/`, `.claude/commands/`, `.claude/`) are
cleaned up via `rmdir`.

## Pre-flight

1. Target path must exist
2. Target must look like a woody-harness project (`.claude/commands/inbox.md` exists) — otherwise nothing to remove

Dirty working tree is fine — you'll likely want to commit `"remove woody-harness"` right after.

## Memory dir is preserved by design

`~/.claude-work/projects/<slug>/memory/` is **never** auto-deleted. Memory
contains per-user feedback, project history, and learned preferences that you
may want to keep even after removing the framework.

If you want it gone, the `--remove` output prints the exact command:

```
Memory dir location (run manually if you want it gone):
  rm -rf /Users/you/.claude-work/projects/-Users-you-Desktop-repo-myproj
```

## Before running `--remove`

1. **Handle your queued inbox prompt** — `_inbox.md` is deleted unconditionally.
   If there's anything live in there, archive it first via
   `bash scripts/archive-prompts.sh`.
2. **Commit your work** — `--remove` doesn't auto-commit. Review with
   `git diff` and commit yourself.

## Sample dry-run output

```
[remove] Target: /path/to/target

Would delete (12 files):
  .claude/commands/inbox.md
  .claude/commands/brief.md
  ...
  docs/prompts/_inbox.md

Would reverse-merge .claude/settings.json:
  → result: {"permissions":{"allow":["Bash(my-custom:*)"]}}

Skipped — user-modified (1):
  docs/prompts/README.md   [hash differs from framework, kept as-is]
    → diff: diff /path/to/target/docs/prompts/README.md /Users/you/woody-harness/templates/prompts/README.md

Would remove empty dirs (if any):
  scripts/, .claude/commands/, .claude/

Would NOT touch:
  CLAUDE.md, RESUME.md, .gitignore
  docs/prompts/_archive/  (your prompt history)
  /Users/you/.claude-work/projects/-path-to-target/  (your memory — preserved)

Memory dir location (run manually if you want it gone):
  rm -rf /Users/you/.claude-work/projects/-path-to-target

Run with --apply to actually delete.
```
