#!/usr/bin/env bash
# session-briefing.sh — SessionStart auto-briefing for Claude Code.
# Prints RESUME.md head + recent commits + latest archive Result block.
set -e

if [ -f RESUME.md ]; then
    echo '=== RESUME.md (head) ==='
    head -30 RESUME.md
    echo ''
fi

echo '=== recent commits ==='
git log --oneline -5 2>/dev/null || true
echo ''

latest=$(ls -t docs/prompts/[0-9]*-*.md docs/prompts/phase-*.md 2>/dev/null | grep -v '_archive/' | head -1 || true)
if [ -n "$latest" ]; then
    echo '=== latest archive Result ==='
    awk '/^## Result$/,0' "$latest" | head -15
fi
