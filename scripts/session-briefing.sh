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

STAGING="$HOME/.claude-work/_shared/lessons-staging.md"
if [ -f "$STAGING" ]; then
    n_total=$(grep -c '^<!-- BEGIN entry ' "$STAGING" 2>/dev/null || echo 0)
    if [ "$n_total" -gt 0 ]; then
        n_raw=$(grep -c '^<!-- BEGIN entry .*state=raw' "$STAGING" 2>/dev/null || echo 0)
        n_cand=$(grep -c '^<!-- BEGIN entry .*state=candidate' "$STAGING" 2>/dev/null || echo 0)
        echo ''
        echo '=== lessons pending ==='
        echo "$n_total entries in staging: $n_raw raw, $n_cand candidate"
        echo "Run 'bash scripts/lessons.sh extract' (raw→candidate) then 'review' (candidate→shared)."
    fi
fi
