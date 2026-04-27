#!/usr/bin/env bash
# statusline.sh — Tandem status indicator for Claude Code statusLine.
# Output: "📥 <state> · <short commit> · last: <emoji>"
# Must be fast (<100ms): only git log, ls, head, grep — no network, no tar.
set -e

root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "(not a git repo)"; exit 0; }
cd "$root"

# Inbox state — strip HTML comments, then check for substantive content
_inbox_real=$(sed '/<!--/,/-->/d' docs/prompts/_inbox.md 2>/dev/null | tr -d '[:space:]')
if [ -n "$_inbox_real" ]; then
    title=$(grep -m1 '^# ' docs/prompts/_inbox.md 2>/dev/null | sed 's/^# //' | cut -c1-30)
    inbox="📥 queued: ${title:-?}"
else
    inbox="📥 empty"
fi

# Queue depth (_queue/*.md, excluding .gitkeep)
queue_seg=""
if [ -d docs/prompts/_queue ]; then
    n_queue=$(find docs/prompts/_queue -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$n_queue" -gt 0 ]; then
        queue_seg=" · 📦 $n_queue"
    fi
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

# Lessons pending (only if shared staging exists)
lessons_seg=""
STAGING="$HOME/.claude-work/_shared/lessons-staging.md"
if [ -f "$STAGING" ]; then
    n_lessons=$(grep -c '^<!-- BEGIN entry ' "$STAGING" 2>/dev/null || echo 0)
    if [ "$n_lessons" -gt 0 ]; then
        lessons_seg=" · 🎓 $n_lessons"
    fi
fi

echo "$inbox$queue_seg · $last_commit · last: $result_emoji$lessons_seg"
