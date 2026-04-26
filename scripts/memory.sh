#!/usr/bin/env bash
# memory.sh — export / import / list the auto-memory dir for the current repo.
# Memory lives at ~/.claude-work/projects/<slug>/memory/ where <slug>=absolute-repo-path with / -> -.
# Usage:
#   bash scripts/memory.sh export                # tarball -> ~/.claude-work/exports/<slug>-memory-<date>.tar.gz
#   bash scripts/memory.sh import <tarball>      # extracts into the current repo's memory dir (refuses if exists; FORCE=1 to override)
#   bash scripts/memory.sh list                  # show current repo's memory dir + contents
set -euo pipefail

memory_dir_for_repo() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not in a git repo" >&2; return 1; }
    local slug
    slug=$(echo "$repo_root" | sed 's|/|-|g')
    echo "$HOME/.claude-work/projects/$slug/memory"
}

cmd="${1:-help}"

case "$cmd" in
    export)
        mem_dir=$(memory_dir_for_repo) || exit 1
        if [ ! -d "$mem_dir" ]; then
            echo "memory dir not found: $mem_dir" >&2
            exit 1
        fi
        export_dir="$HOME/.claude-work/exports"
        mkdir -p "$export_dir"
        slug_name=$(basename "$(dirname "$mem_dir")")
        date_str=$(date +%Y%m%d-%H%M)
        archive="$export_dir/$slug_name-memory-$date_str.tar.gz"
        tar -czf "$archive" -C "$(dirname "$mem_dir")" memory
        echo "exported: $archive"
        echo "size:     $(du -h "$archive" | cut -f1)"
        echo "files:    $(tar -tzf "$archive" | wc -l | tr -d ' ')"
        ;;
    import)
        archive="${2:-}"
        if [ -z "$archive" ] || [ ! -f "$archive" ]; then
            echo "usage: bash scripts/memory.sh import <tarball>" >&2
            exit 1
        fi
        mem_dir=$(memory_dir_for_repo) || exit 1
        target_parent=$(dirname "$mem_dir")
        mkdir -p "$target_parent"
        if [ -d "$mem_dir" ] && [ "${FORCE:-0}" != "1" ]; then
            echo "memory dir already exists: $mem_dir" >&2
            echo "to overwrite: FORCE=1 bash scripts/memory.sh import $archive" >&2
            exit 1
        fi
        rm -rf "$mem_dir"
        tar -xzf "$archive" -C "$target_parent"
        echo "imported into: $mem_dir"
        echo "files:"
        ls "$mem_dir"
        ;;
    list)
        mem_dir=$(memory_dir_for_repo) || exit 1
        echo "memory dir: $mem_dir"
        if [ -d "$mem_dir" ]; then
            echo ""
            ls -la "$mem_dir"
        else
            echo "(does not exist — bootstrap.sh creates it for new projects, or run 'memory.sh import' to restore from a tarball)"
        fi
        ;;
    help|--help|-h)
        sed -n '2,8p' "$0"
        ;;
    *)
        echo "unknown command: $cmd" >&2
        sed -n '2,8p' "$0" >&2
        exit 1
        ;;
esac
