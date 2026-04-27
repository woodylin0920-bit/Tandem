#!/usr/bin/env bash
# notify-blocked.sh — alert when Claude Code executor is blocked (permission prompt / idle).
# Triggered by Notification event hook in .claude/settings.json.
# afplay backgrounded so the hook returns instantly; osascript best-effort.
afplay /System/Library/Sounds/Funk.aiff & disown 2>/dev/null || true
osascript -e 'display notification "⚠️ executor needs your input" with title "Tandem · blocked"' || echo "[notify] osascript failed (host permission?)" >&2
