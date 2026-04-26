#!/usr/bin/env bash
# statusline.sh — woody-harness status indicator for Claude Code statusLine.
# Output: "📥 <state> · <short commit> · last: <emoji>"
# Must be fast (<100ms): only git log, ls, head, grep — no network, no tar.
set -e

root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "(not a git repo)"; exit 0; }
cd "$root"

# Inbox state — file > 5 bytes counts as "queued"
if [ -s docs/prompts/_inbox.md ] && [ "$(wc -c < docs/prompts/_inbox.md | tr -d ' ')" -gt 5 ]; then
    title=$(grep -m1 '^# ' docs/prompts/_inbox.md 2>/dev/null | sed 's/^# //' | cut -c1-30)
    inbox="📥 queued: ${title:-?}"
else
    inbox="📥 empty"
fi

# Last commit (short SHA + first 35 chars of subject)
last_commit=$(git log -1 --format='%h %s' 2>/dev/null | cut -c1-44)

# Latest archive Result Status emoji
latest_archive=$(ls -t docs/prompts/[0-9]*-*.md docs/prompts/phase-*.md 2>/dev/null | grep -v '_archive/' | head -1)
result_emoji="—"
if [ -n "$latest_archive" ]; then
    status_line=$(grep -m1 '^\*\*Status\*\*' "$latest_archive" 2>/dev/null || echo "")
    case "$status_line" in
        *"✅"*) result_emoji="✅" ;;
        *"⚠️"*) result_emoji="⚠️" ;;
        *"❌"*) result_emoji="❌" ;;
    esac
fi

echo "$inbox · $last_commit · last: $result_emoji"
