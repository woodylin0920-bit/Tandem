#!/usr/bin/env bash
# Archive dated prompts under docs/prompts/_archive/<YYYY-MM>/
# Usage: bash scripts/archive-prompts.sh [--dry-run]
set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

cd "$(git rev-parse --show-toplevel)" || { echo "not in a git repo" >&2; exit 1; }

STAGING="$HOME/.claude-work/_shared/lessons-staging.md"

# Detect lesson signals from an archive file. If detected, append raw entry to staging (idempotent by archive id).
detect_and_stage_lesson() {
    local archive_file="$1"
    local id
    id=$(basename "$archive_file" .md)

    # Skip under dry-run (avoid mutating staging during dry-runs)
    [ "$DRY_RUN" = 1 ] && return 0

    # Skip if shared dir not yet bootstrapped (some early projects haven't run shared seed)
    [ -d "$(dirname "$STAGING")" ] || return 0

    # Idempotency: skip if already in staging
    if [ -f "$STAGING" ] && grep -q "^<!-- BEGIN entry id=$id " "$STAGING"; then
        return 0
    fi

    # Detect signals
    local has_blocked has_blockers has_fail has_keyword
    has_blocked=$(grep -m1 -E '^\*\*Status\*\*.*❌' "$archive_file" 2>/dev/null || true)
    has_blockers=$(grep -m1 -E '^\*\*Blockers\*\*:' "$archive_file" 2>/dev/null | grep -viE 'none|^\*\*Blockers\*\*: *$' || true)
    has_fail=$(grep -m1 -E '\bFAIL\b' "$archive_file" 2>/dev/null | grep -viE 'PASS|/ FAIL$' || true)
    has_keyword=$(grep -m1 -iE 'next time|should (have|do|run|abort)|lesson learned' "$archive_file" 2>/dev/null || true)

    if [ -z "$has_blocked" ] && [ -z "$has_blockers" ] && [ -z "$has_fail" ] && [ -z "$has_keyword" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$STAGING")"
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    {
        echo "<!-- BEGIN entry id=$id state=raw timestamp=$ts -->"
        echo "- archive: $archive_file"
        [ -n "$has_blocked" ] && echo "- status: ❌ blocked"
        echo "- signals:"
        [ -n "$has_blocked" ] && echo "  - \"$has_blocked\""
        [ -n "$has_blockers" ] && echo "  - \"$has_blockers\""
        [ -n "$has_fail" ] && echo "  - \"$has_fail\""
        [ -n "$has_keyword" ] && echo "  - \"$has_keyword\""
        echo "- excerpt: |"
        awk '/^## Result$/,0' "$archive_file" | head -25 | sed 's/^/    /'
        echo "<!-- END entry -->"
        echo ""
    } >> "$STAGING"

    echo "[archive] lesson signal detected → staged: $id"
}

PROMPTS_DIR="docs/prompts"
ARCHIVE_ROOT="$PROMPTS_DIR/_archive"
shopt -s nullglob

moved=0

# Dated archives: 2026-04-28-foo.md
for f in "$PROMPTS_DIR"/[0-9][0-9][0-9][0-9]-*.md; do
    base=$(basename "$f")
    yyyymm=$(echo "$base" | grep -oE '^[0-9]{4}-[0-9]{2}')
    [ -z "$yyyymm" ] && continue

    target_dir="$ARCHIVE_ROOT/$yyyymm"
    target="$target_dir/$base"

    detect_and_stage_lesson "$f"

    if [ "$DRY_RUN" = 1 ]; then
        echo "DRY: $base -> _archive/$yyyymm/"
    else
        mkdir -p "$target_dir"
        git mv "$f" "$target" 2>/dev/null || mv "$f" "$target"
        echo "moved $base -> _archive/$yyyymm/"
    fi
    moved=$((moved + 1))
done

# Legacy "phase-*.md" naming (pre-2026-04-28)
for f in "$PROMPTS_DIR"/phase-*.md; do
    base=$(basename "$f")
    target_dir="$ARCHIVE_ROOT/legacy"
    target="$target_dir/$base"

    if [ "$DRY_RUN" = 1 ]; then
        echo "DRY: $base -> _archive/legacy/"
    else
        mkdir -p "$target_dir"
        git mv "$f" "$target" 2>/dev/null || mv "$f" "$target"
        echo "moved $base -> _archive/legacy/"
    fi
    moved=$((moved + 1))
done

if [ "$moved" = 0 ]; then
    echo "nothing to archive."
elif [ "$DRY_RUN" = 0 ]; then
    echo ""
    echo "$moved file(s) moved. Review with 'git status', then commit:"
    echo "  git commit -m 'chore: archive prompts to _archive/'"
fi
