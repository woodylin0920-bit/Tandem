# Dogfood: bootstrap.sh upgrade/remove (2026-04-28)

**Span**: S-1 + polish-r5 + rename shipped → S-1 production-validated against 4 scenarios.
**Tester**: sonnet executor in dogfood inbox round.

## Scenarios run

| # | Scenario | Status |
|---|---|---|
| 1 | Aged 4d-era project upgraded to current | ✅ |
| 2 | User-customized project upgraded (preserves customization) | ✅ |
| 3 | Re-upgrade idempotency | ✅ |
| 4 | Remove after upgrade (full lifecycle) | ✅ |

## Findings — bugs / regressions

- (none) — all 4 scenarios behaved correctly.

> One pre-flight discrepancy worth tracking (see UX section below).

## Findings — UX awkwardness

1. **`--apply` output still uses "Would" language** — after passing `--apply`, output still prints "Would overwrite (N)" and "Would delete (N)" instead of "Overwriting (N)" / "Deleted (N)". First-time users may think nothing happened. The trailing "Done. N files written/deleted." is the only signal that --apply actually ran. (Minor — but confusing.)

2. **Post-apply `git diff` hint is incomplete** — after upgrade `--apply`, the output says:
   ```
   Run 'git -C <path> diff' to inspect.
   ```
   But `git diff` only shows *tracked* modified files (e.g. `settings.json`). New files copied in (e.g. `brief.md`, `sync.md`) show up as `??` untracked — invisible to `git diff`. Better hint: `git -C <path> status` or `git -C <path> add -A && git -C <path> diff --cached --stat`.

3. **Dirty-tree pre-flight: warns but continues** — `UPGRADE.md` says "pre-flight checks... clean tree required", but actual behavior on a dirty tree is:
   ```
   [upgrade] WARN: target working tree is dirty (continuing anyway)
   ```
   The upgrade still runs. Docs say it should block; reality is WARN+continue. Not necessarily wrong behavior (maybe intentional soft-gate), but docs/behavior mismatch could confuse users who expect a hard abort.

4. **"Done. 1 files written" when Would overwrite (0)** — in Scenario 2, overwrite count was 0 but settings.json was still merged (counted as 1 write). The 1 write comes from the settings.json merge path, which is a separate category from "Would overwrite". The count is technically accurate but reads as surprising when the overwrite section explicitly said "(0)".

5. **`diff` hint for user-modified files has long tmpdir paths** — the skipped-file hint is:
   ```
   → diff: diff /very/long/path/to/target/docs/prompts/README.md /very/long/path/to/harness/templates/prompts/README.md
   ```
   This is correct and runnable, but the path length makes it hard to read at a glance on a terminal. A relative hint like `diff <target> <framework-template>` might be cleaner. Low priority.

## Findings — missing / unclear output

- After `--remove --apply`, there is no `git status` / `git diff` hint printed (upgrade prints one, remove doesn't). For symmetry, remove could print: `Run 'git -C <path> status' to see deleted files before committing.`
- The `[upgrade] WARN: target working tree is dirty` message is easy to miss — it's one line before the main output starts, no visual separator.

## What worked well

- **Dry-run section structure** (`Would overwrite / Would merge / Up-to-date / Skipped — user-modified`) is clear and complete. Each category makes the expected outcome obvious before applying.
- **`[new file]` label** in dry-run clearly marks net-new files vs. content overwrites — excellent UX.
- **User customization detection (hash-compare)** worked correctly in both upgrade (S2) and remove (S4): `docs/prompts/README.md` was skipped and user content preserved.
- **User-only permissions preserved** through upgrade merge (`Bash(jq:*)`, `Bash(my-custom-tool:*)`) and reverse-merged cleanly through remove (only user-only perms remained).
- **Memory dir handling** — not touched by remove, printed explicit "run manually if you want it gone" command. Exactly right behavior.
- **Empty dir cleanup** (`scripts/`, `.claude/commands/`, `.claude/`) worked correctly in remove.
- **CLAUDE.md / RESUME.md / .gitignore** never touched by any mode.
- **Idempotency** (S3): re-running upgrade on already-upgraded project shows all files Up-to-date, merge shows `= up-to-date`. No phantom changes.
- **Remove dry-run shows reverse-merge result inline** (`→ result: {"permissions":...}`) — this is genuinely excellent: user sees exactly what settings.json will look like before committing to `--apply`.

## Suggested next round

1. Fix `--apply` to use active-tense output headers ("Overwriting (N)" / "Deleted (N)") instead of "Would" language.
2. Fix post-upgrade hint to suggest `git status` (or `git add -A && git diff --cached --stat`) instead of bare `git diff`.
3. Decide: should dirty-tree abort or WARN? Update UPGRADE.md to match whichever is intended.
4. Add post-remove hint: `git -C <path> status` to see deleted files.
5. (Low) Consider showing diff hint for user-modified files as short relative paths or labeled tokens.

## Raw output references

- Scenario 1 dry-run:
```
[upgrade] Target: /tmp/wh-dogfood-.../aged-project
[upgrade] Framework: /Users/woody/Desktop/repo/public/woody-harness

Would overwrite (6):
  .claude/commands/brief.md                    [new file]
  .claude/commands/sync.md                     [new file]
  scripts/memory.sh                            [new file]
  scripts/statusline.sh                        [new file]
  scripts/session-briefing.sh                  [new file]
  scripts/notify-blocked.sh                    [new file]

Would merge .claude/settings.json:
  + permissions.allow new entries:
      Bash(say:*)
      Bash(bash scripts/memory.sh:*)
      Bash(bash scripts/notify-blocked.sh:*)
  + statusLine (target had none, adding framework's)

Up-to-date (5):
  .claude/commands/inbox.md
  .claude/commands/codex-audit.md
  .claude/commands/phase-gate.md
  scripts/archive-prompts.sh
  docs/prompts/README.md

Run with --apply to actually write changes.
```

- Scenario 2 dry-run (skip-if-modified section):
```
Would overwrite (0):

Would merge .claude/settings.json:
  = permissions.allow up-to-date
  = statusLine kept (target's wins)

Skipped — user-modified (1):
  docs/prompts/README.md
    → diff: diff <target>/docs/prompts/README.md <harness>/templates/prompts/README.md

Up-to-date (10):
  [all 10 framework files listed]

Run with --apply to actually write changes.
```

- Scenario 3 dry-run (idempotency):
```
[upgrade] WARN: target working tree is dirty (continuing anyway)

Would overwrite (0):

Would merge .claude/settings.json:
  = permissions.allow up-to-date
  = statusLine kept (target's wins)

Up-to-date (11):
  [all 11 files listed]
```

- Scenario 4 dry-run (reverse-merge):
```
[remove] Target: /tmp/wh-dogfood-.../customized

Would delete (11 files):
  [framework files listed]

Would reverse-merge .claude/settings.json:
  → result: {"permissions":{"allow":["Bash(jq:*)","Bash(my-custom-tool:*)"]}}

Skipped — user-modified (1):
  docs/prompts/README.md   [hash differs from framework, kept as-is]

Would remove empty dirs (if any):
  scripts/, .claude/commands/, .claude/

Would NOT touch:
  CLAUDE.md, RESUME.md, .gitignore
  docs/prompts/_archive/  (your prompt history)
  /Users/woody/.claude-work/projects/.../  (your memory — preserved)

Memory dir location (run manually if you want it gone):
  rm -rf /Users/woody/.claude-work/projects/...
```
