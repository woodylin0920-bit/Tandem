#!/usr/bin/env bash
# memory.sh — export / import / list / sync the auto-memory dir for the current repo.
# Memory lives at ~/.claude-work/projects/<slug>/memory/ where <slug>=absolute-repo-path with / -> -.
# Usage:
#   bash scripts/memory.sh export                # tarball -> ~/.claude-work/exports/<slug>-memory-<date>.tar.gz
#   bash scripts/memory.sh import <tarball>      # extracts into the current repo's memory dir (refuses if exists; FORCE=1 to override)
#   bash scripts/memory.sh list                  # show current repo's memory dir + contents
#   bash scripts/memory.sh sync                  # symlink shared layer into project memory + regenerate combined MEMORY.md
set -euo pipefail

memory_dir_for_repo() {
    # Walk $PWD (not git rev-parse) to preserve the user-facing path and match slugs
    # computed by bootstrap.sh, avoiding canonical-path divergence on macOS (/tmp→/private/tmp).
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; then
            local slug
            slug=$(echo "$dir" | sed 's|/|-|g')
            echo "$HOME/.claude-work/projects/$slug/memory"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    echo "not in a git repo" >&2
    return 1
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
    sync)
        proj_mem=$(memory_dir_for_repo) || exit 1
        shared_mem="$HOME/.claude-work/_shared/memory"

        if [ ! -d "$proj_mem" ]; then
            echo "error: no project memory dir for $(pwd) — run bootstrap.sh first" >&2
            exit 1
        fi
        if [ ! -d "$shared_mem" ]; then
            echo "error: no shared layer at $shared_mem — run bootstrap.sh on a new project to seed it, or manually mkdir + populate" >&2
            exit 1
        fi

        linked=()
        already_linked=()
        relinked=()
        overridden=()
        expected_prefix="../../../_shared/memory"

        for f in "$shared_mem"/*.md; do
            [ -f "$f" ] || continue
            name=$(basename "$f")
            [ "$name" = "MEMORY.md" ] && continue
            target="$proj_mem/$name"
            expected_link="$expected_prefix/$name"

            if [ ! -e "$target" ] && [ ! -L "$target" ]; then
                ln -s "$expected_link" "$target"
                linked+=("$name")
            elif [ -L "$target" ]; then
                current=$(readlink "$target")
                if [ "$current" = "$expected_link" ]; then
                    already_linked+=("$name")
                else
                    rm "$target"
                    ln -s "$expected_link" "$target"
                    relinked+=("$name")
                fi
            else
                overridden+=("$name")
            fi
        done

        # Regenerate MEMORY.md
        memory_md="$proj_mem/MEMORY.md"
        shared_entries=""
        [ -f "$shared_mem/MEMORY.md" ] && shared_entries=$(cat "$shared_mem/MEMORY.md") || true

        project_local=""
        if [ -f "$memory_md" ]; then
            if grep -q "<!-- BEGIN project-local" "$memory_md"; then
                project_local=$(sed -n '/<!-- BEGIN project-local/,/<!-- END project-local -->/p' "$memory_md" | sed '1d;$d')
            else
                project_local=$(cat "$memory_md")
            fi
        fi

        # Add override entries to project-local if not already present
        for name in "${overridden[@]:-}"; do
            [ -z "$name" ] && continue
            base="${name%.md}"
            if ! printf '%s\n' "$project_local" | grep -qF "$name"; then
                project_local="${project_local}
- [${base} (project override)](${name}) [OVERRIDE] — local version of shared/${name}"
            fi
        done

        {
            echo "<!-- BEGIN shared (auto-managed by scripts/memory.sh sync — do not edit between markers) -->"
            [ -n "$shared_entries" ] && printf '%s\n' "$shared_entries" || true
            echo "<!-- END shared -->"
            echo ""
            echo "<!-- BEGIN project-local (you can edit this section freely) -->"
            [ -n "$project_local" ] && printf '%s\n' "$project_local" || true
            echo "<!-- END project-local -->"
        } > "$memory_md"

        # Count shared files and entries for summary
        n_shared=0
        for f in "$shared_mem"/*.md; do
            [ -f "$f" ] || continue
            [ "$(basename "$f")" = "MEMORY.md" ] && continue
            n_shared=$((n_shared + 1))
        done
        n_shared_entries=$(grep -c '^- ' "$shared_mem/MEMORY.md" 2>/dev/null || echo "0")

        proj_root=$(git rev-parse --show-toplevel 2>/dev/null) || proj_root="$(pwd)"
        echo "[sync] Project: $proj_root"
        echo "[sync] Shared: $shared_mem ($n_shared files)"
        echo ""

        n_linked=${#linked[@]}
        printf 'Linked (%d):' "$n_linked"
        if [ "$n_linked" -gt 0 ]; then
            echo ""
            for name in "${linked[@]}"; do echo "  $name"; done
        else
            echo " (none)"
        fi

        n_already=${#already_linked[@]}
        echo "(${n_already} already in sync)"

        n_relinked=${#relinked[@]}
        printf 'Relinked (%d):' "$n_relinked"
        if [ "$n_relinked" -gt 0 ]; then
            echo ""
            for name in "${relinked[@]}"; do echo "  $name"; done
        else
            echo " (none)"
        fi

        n_overridden=${#overridden[@]}
        printf 'Overridden by project (%d):' "$n_overridden"
        if [ "$n_overridden" -gt 0 ]; then
            echo ""
            for name in "${overridden[@]}"; do
                echo "  $name   [project file kept; shared entry shadowed]"
            done
        else
            echo " (none)"
        fi

        echo ""
        echo "MEMORY.md regenerated: shared section ($n_shared_entries entries) + project-local section preserved."
        echo ""
        echo "Done."
        ;;
    help|--help|-h)
        sed -n '2,9p' "$0"
        ;;
    *)
        echo "unknown command: $cmd" >&2
        sed -n '2,9p' "$0" >&2
        exit 1
        ;;
esac
