# Lessons loop

The lessons loop turns inbox rounds that hit problems into reusable feedback memories — automatically staging candidates, then user-reviewed promotion to the cross-project shared layer.

## How it works

1. **Auto-detect on archive.** Every time `scripts/archive-prompts.sh` runs (after `/inbox` completes), it scans the archived prompt's `## Result` block for signals:
   - `Status: ❌ blocked`
   - `Blockers: <non-empty>`
   - Any `FAIL` line in verification
   - Keyword hits: "next time", "should have/do/run/abort", "lesson learned"
2. **Stage raw signal.** If any signal hits, archive-prompts.sh appends a `state=raw` entry to `~/.claude-work/_shared/lessons-staging.md` (cross-project staging — same shared layer as `_shared/memory/`). Idempotent by archive basename.
3. **User refines.** When ready, run `bash scripts/lessons.sh extract`. This invokes `claude -p` headless to refine each raw signal into a structured `state=candidate` lesson with name + description + Why/How-to-apply body.
4. **User reviews.** Run `bash scripts/lessons.sh review`. Walks each candidate interactively: `[p]romote-shared / [d]elete / [s]kip / [q]uit`. Default = promote-shared (Enter). Promoted lessons land in `~/.claude-work/_shared/memory/<slug>.md` and the index `_shared/memory/MEMORY.md` gets a new row.

## Why automatic + user-reviewed

The vision is a self-improving AI partner — but Tandem's ethos is human-in-loop. Auto-detection ensures lessons aren't lost (you'd forget to run `/lessons` manually). User review ensures the shared memory layer doesn't get polluted with bad lessons.

## Discovery

You'll know there are pending lessons via:

- **Statusline**: `📥 inbox · <commit> · last: ✅ · 🎓 3` — the `🎓 N` segment shows total staging count.
- **SessionStart briefing**: includes a `=== lessons pending ===` block when staging is non-empty, with raw/candidate breakdown and the next command to run.

## Subcommands

| Command | What it does |
|---|---|
| `bash scripts/lessons.sh count` | print total + raw/candidate breakdown |
| `bash scripts/lessons.sh list` | list each entry with id + state |
| `bash scripts/lessons.sh extract` | refine all `state=raw` entries via headless claude |
| `bash scripts/lessons.sh review` | interactive promote/delete on `state=candidate` entries |

## Fallback when `claude` CLI unavailable

If `claude` is not in `$PATH`, `lessons.sh extract` prints raw entries to stdout with instructions to paste them into a planner session manually. Useful when working from a machine without Claude Code installed.

## Cross-project lessons

Staging lives at `~/.claude-work/_shared/lessons-staging.md` (user-level, not per-project). Lessons captured in project A become available to project B after promotion. This is the same architecture as `_shared/memory/` — cross-project by design.

## Related

- [SHARED_MEMORY.md](SHARED_MEMORY.md) — shared memory layer architecture
- [MEMORY_SYSTEM.md](MEMORY_SYSTEM.md) — feedback memory format + how memory loads at session start
- [MODEL_GUIDE.md](MODEL_GUIDE.md) — model + effort selection (`claude -p` headless invocation in extract uses your default model)
