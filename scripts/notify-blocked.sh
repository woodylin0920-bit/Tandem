#!/usr/bin/env bash
# notify-blocked.sh — alert when Claude Code executor is blocked (permission prompt / idle).
# Triggered by Notification event hook in .claude/settings.json.
# Cooldown: 60s between alerts; singleton: prevents overlapping afplay.

COOLDOWN=60
WORKDIR="$HOME/.claude-work"
LAST_FILE="$WORKDIR/.notify-last"
LOCK_DIR="$WORKDIR/.notify.lock.d"

# Cooldown check
now=$(date +%s)
last=$(cat "$LAST_FILE" 2>/dev/null || echo 0)
if [ $((now - last)) -lt $COOLDOWN ]; then
    exit 0
fi
echo "$now" > "$LAST_FILE"

# Singleton: prevent overlapping afplay
mkdir "$LOCK_DIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

afplay /System/Library/Sounds/Funk.aiff & disown 2>/dev/null || true
osascript -e 'display notification "⚠️ executor needs your input" with title "Tandem · blocked"' || echo "[notify] osascript failed (host permission?)" >&2
