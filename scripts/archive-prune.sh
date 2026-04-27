#!/usr/bin/env bash
# archive-prune.sh — compact old monthly archive dirs into .tar.gz files.
# Monthly dirs older than --keep-months are tarred into _archive/legacy/<YYYY-MM>.tar.gz.
# Run manually; not called automatically.
#
# Usage:
#   bash scripts/archive-prune.sh [--keep-months N] [--dry-run]
set -euo pipefail
cd "$(git rev-parse --show-toplevel)" || { echo "not in a git repo" >&2; exit 1; }

ARCHIVE_ROOT="docs/prompts/_archive"
LEGACY_DIR="$ARCHIVE_ROOT/legacy"
KEEP_MONTHS=3
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --keep-months) KEEP_MONTHS="${2:?--keep-months requires N}"; shift 2 ;;
        --dry-run)     DRY_RUN=1; shift ;;
        *) echo "usage: archive-prune.sh [--keep-months N] [--dry-run]" >&2; exit 1 ;;
    esac
done

cutoff=$(date -v "-${KEEP_MONTHS}m" +%Y-%m 2>/dev/null || date -d "-${KEEP_MONTHS} months" +%Y-%m)
echo "[archive-prune] keeping months >= $cutoff (--keep-months $KEEP_MONTHS)"
[ "$DRY_RUN" -eq 1 ] && echo "[archive-prune] dry-run mode — no changes"

mkdir -p "$LEGACY_DIR"

pruned=0
for dir in "$ARCHIVE_ROOT"/[0-9][0-9][0-9][0-9]-[0-9][0-9]; do
    [ -d "$dir" ] || continue
    month=$(basename "$dir")
    # Skip if month is within keep window (string compare: YYYY-MM is lexicographically sortable)
    if [[ "$month" > "$cutoff" || "$month" == "$cutoff" ]]; then
        echo "[archive-prune] keep: $month"
        continue
    fi
    tarball="$LEGACY_DIR/$month.tar.gz"
    echo "[archive-prune] prune: $month → $tarball"
    if [ "$DRY_RUN" -eq 0 ]; then
        tar czf "$tarball" -C "$ARCHIVE_ROOT" "$month"
        rm -rf "$dir"
        pruned=$((pruned + 1))
    fi
done

if [ "$DRY_RUN" -eq 0 ] && [ "$pruned" -gt 0 ]; then
    echo "[archive-prune] pruned $pruned month(s)"
else
    [ "$pruned" -eq 0 ] && echo "[archive-prune] nothing to prune"
fi
