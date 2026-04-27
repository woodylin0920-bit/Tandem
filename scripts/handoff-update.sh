#!/usr/bin/env bash
# handoff-update.sh — update project_current_handoff.md memory after inbox/auto close.
# Called at end of /inbox flow to keep /brief up-to-date automatically.
#
# Usage: bash scripts/handoff-update.sh <archive-file-path> [inbox-status]
#   archive-file-path: path to the archived prompt file (with ## Result block)
#   inbox-status: "empty" | "queued" (default: empty)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)" || { echo "not in a git repo" >&2; exit 1; }

archive_file="${1:-}"
inbox_status="${2:-empty}"

if [ -z "$archive_file" ] || [ ! -f "$archive_file" ]; then
    echo "[handoff] usage: handoff-update.sh <archive-file> [inbox-status]" >&2
    exit 1
fi

# Determine project memory dir
proj_mem="$(git rev-parse --show-toplevel)/.claude-work/$(basename "$(git rev-parse --show-toplevel)")/memory"
if [ -n "${CLAUDE_WORK_DIR:-}" ]; then
    proj_mem="$CLAUDE_WORK_DIR/memory"
fi
# Fallback to the known path pattern used by auto-memory
proj_slug=$(git rev-parse --show-toplevel | tr '/' '-' | sed 's/^-//')
proj_mem="$HOME/.claude-work/projects/$proj_slug/memory"

mkdir -p "$proj_mem"

handoff_file="$proj_mem/project_current_handoff.md"

# Extract last commit
last_commit=$(git log -1 --format='%h %s' 2>/dev/null || echo "unknown")

# Extract Result block from archive
result_block=$(awk '/^## Result$/,0' "$archive_file" | head -10 | tail -n +2)
status_line=$(echo "$result_block" | grep -m1 -E '^(\*\*Status\*\*|Status):' || echo "Status: unknown")
commits_line=$(echo "$result_block" | grep -m1 '^Commits:' || echo "")
notes_line=$(echo "$result_block" | grep -m1 '^Notes:' || echo "")

archive_slug=$(basename "$archive_file" .md)

cat > "$handoff_file" <<EOF
---
name: current handoff state ($(date +%Y-%m-%d))
description: Latest inbox/auto round status — what shipped, what's next
type: project
---

Last commit: $last_commit
Archive: $archive_slug
$status_line
${commits_line}
${notes_line}

_inbox.md: $inbox_status
**Why:** Auto-updated at end of /inbox or /auto run so /brief always shows current state.
**How to apply:** Use to orient at start of new session; check git log to verify.
EOF

echo "[handoff] updated $handoff_file"
