#!/usr/bin/env bash
# Archive dated prompts under docs/prompts/_archive/<YYYY-MM>/
# Usage: bash scripts/archive-prompts.sh [--dry-run]
set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

cd "$(git rev-parse --show-toplevel)" || { echo "not in a git repo" >&2; exit 1; }

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
