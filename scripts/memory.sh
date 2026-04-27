#!/usr/bin/env bash
# memory.sh — export / import / list / sync / promote the auto-memory dir for the current repo.
# Memory lives at ~/.claude-work/projects/<slug>/memory/ where <slug>=absolute-repo-path with / -> -.
# Usage:
#   bash scripts/memory.sh export                # tarball -> ~/.claude-work/exports/<slug>-memory-<date>.tar.gz
#   bash scripts/memory.sh import <tarball>      # extracts into the current repo's memory dir (refuses if exists; FORCE=1 to override)
#   bash scripts/memory.sh list                  # show current repo's memory dir + contents
#   bash scripts/memory.sh sync                  # pull shared, symlink shared layer into project memory, regenerate MEMORY.md
#   bash scripts/memory.sh promote [--batch <file1,file2,...>]   # promote project memory entries to shared layer (interactive or batch)
set -euo pipefail

SHARED_DIR="$HOME/.claude-work/shared"
SHARED_MEM="$SHARED_DIR/memory"

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

check_shared_dir() {
    if [ ! -d "$SHARED_DIR" ]; then
        echo "error: no shared layer at $SHARED_DIR — run 'bash scripts/shared-init.sh' first" >&2
        exit 1
    fi
    if [ ! -d "$SHARED_DIR/.git" ]; then
        echo "error: $SHARED_DIR exists but is not a git repo — run 'bash scripts/shared-init.sh' to fix" >&2
        exit 1
    fi
}

shared_pull() {
    local orig_dir="$PWD"
    cd "$SHARED_DIR"
    if ! git pull --rebase 2>&1; then
        echo ""
        echo "error: git pull --rebase failed in $SHARED_DIR" >&2
        echo "  There may be a merge conflict. To resolve:" >&2
        echo "    cd $SHARED_DIR" >&2
        echo "    git status       # see conflicting files" >&2
        echo "    # edit files to resolve conflicts" >&2
        echo "    git add <files>" >&2
        echo "    git rebase --continue" >&2
        echo "  Then re-run: bash scripts/memory.sh sync" >&2
        cd "$orig_dir"
        exit 1
    fi
    cd "$orig_dir"
}

shared_push() {
    local commit_msg="$1"
    local orig_dir="$PWD"
    cd "$SHARED_DIR"
    git add -A
    if git diff --cached --quiet; then
        cd "$orig_dir"
        return 0
    fi
    git commit -m "$commit_msg"
    if ! git push 2>&1; then
        echo "error: git push to shared remote failed" >&2
        echo "  Check: cd $SHARED_DIR && git push" >&2
        cd "$orig_dir"
        exit 1
    fi
    cd "$orig_dir"
}

_validate_shared_files() {
    local dir="$1"
    local ok=1
    local shared_root
    shared_root=$(realpath "$SHARED_DIR")

    for f in "$dir"/*.md; do
        [ -e "$f" ] || continue
        if [ -L "$f" ]; then
            echo "[memory] refused symlink: $f" >&2
            ok=0
            continue
        fi
        real=$(realpath "$f" 2>/dev/null || true)
        case "$real" in
            "$shared_root"/*) ;;
            *)
                echo "[memory] refused path outside shared dir: $f (resolves to $real)" >&2
                ok=0
                ;;
        esac
        ext="${f##*.}"
        if [ "$ext" != "md" ]; then
            echo "[memory] refused non-.md file: $f" >&2
            ok=0
        fi
    done
    [ "$ok" -eq 1 ]
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
        check_shared_dir

        if [ ! -d "$proj_mem" ]; then
            echo "error: no project memory dir for $(pwd) — run bootstrap.sh first" >&2
            exit 1
        fi
        if [ ! -d "$SHARED_MEM" ]; then
            echo "error: no shared memory dir at $SHARED_MEM — run 'bash scripts/shared-init.sh' first" >&2
            exit 1
        fi

        # Pull latest from shared remote
        shared_pull

        # Validate shared files before symlinking
        if ! _validate_shared_files "$SHARED_MEM"; then
            echo "error: shared layer contains unsafe files (symlinks or non-.md); aborting sync" >&2
            exit 1
        fi

        linked=()
        already_linked=()
        relinked=()
        overridden=()
        expected_prefix="../../../shared/memory"

        for f in "$SHARED_MEM"/*.md; do
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
        [ -f "$SHARED_MEM/MEMORY.md" ] && shared_entries=$(cat "$SHARED_MEM/MEMORY.md") || true

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
        for f in "$SHARED_MEM"/*.md; do
            [ -f "$f" ] || continue
            [ "$(basename "$f")" = "MEMORY.md" ] && continue
            n_shared=$((n_shared + 1))
        done
        n_shared_entries=$(grep -c '^- ' "$SHARED_MEM/MEMORY.md" 2>/dev/null || echo "0")

        proj_root=$(git rev-parse --show-toplevel 2>/dev/null) || proj_root="$(pwd)"
        echo "[sync] Project: $proj_root"
        echo "[sync] Shared:  $SHARED_MEM ($n_shared files)"
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
    promote)
        proj_mem=$(memory_dir_for_repo) || exit 1
        check_shared_dir
        script_self="$(cd "$(dirname -- "$0")" && pwd)/$(basename -- "$0")"

        # --batch mode: promote a comma-separated list of files non-interactively
        BATCH_MODE=0
        BATCH_FILES=()
        if [ "${2:-}" = "--batch" ]; then
            BATCH_MODE=1
            IFS=',' read -ra BATCH_FILES <<< "${3:-}"
            if [ ${#BATCH_FILES[@]} -eq 0 ]; then
                echo "usage: bash scripts/memory.sh promote --batch file1.md,file2.md,..." >&2
                exit 1
            fi
        fi

        # Pre-flight
        if [ ! -d "$proj_mem" ]; then
            echo "error: no project memory dir for $(pwd) — run bootstrap.sh first" >&2
            exit 1
        fi
        if [ ! -d "$SHARED_MEM" ]; then
            echo "error: no shared memory dir at $SHARED_MEM — run 'bash scripts/shared-init.sh' first" >&2
            exit 1
        fi
        if [ ! -f "$proj_mem/MEMORY.md" ] || ! grep -q "<!-- BEGIN project-local" "$proj_mem/MEMORY.md"; then
            echo "error: project MEMORY.md missing T-1a markers — run 'bash scripts/memory.sh sync' first" >&2
            exit 1
        fi

        # Pull latest before promoting
        shared_pull

        # Parse one frontmatter field from a file
        parse_field() {
            awk -v field="$1" '
                /^---$/ {fm++; next}
                fm==1 && $0 ~ "^"field":" {sub("^"field":[ \t]*", ""); print; exit}
            ' "$2"
        }

        # Read a single meaningful character, skipping newlines
        read_key() {
            local ans rc
            while true; do
                IFS= read -r -n 1 ans
                rc=$?
                if [ $rc -ne 0 ] && [ -z "$ans" ]; then
                    printf 'q'; return
                fi
                case "$ans" in
                    $'\n'|$'\r'|'') continue ;;
                    *) printf '%s' "$ans"; return ;;
                esac
            done
        }

        # Remove entry matching pattern from project-local section of MEMORY.md
        remove_from_project_local() {
            local memory_md="$1" entry_pattern="$2" tmp
            tmp=$(mktemp)
            awk -v pat="$entry_pattern" '
                /<!-- BEGIN project-local/ {in_local=1; print; next}
                /<!-- END project-local/ {in_local=0; print; next}
                in_local && index($0, pat) > 0 {next}
                {print}
            ' "$memory_md" > "$tmp"
            mv "$tmp" "$memory_md"
        }

        # Promote a single file to shared (used by both interactive and batch modes)
        # Returns 0 on success, 1 on skip/conflict-cancel
        promote_file() {
            local file="$1" name fm_name fm_desc
            name=$(basename "$file")
            fm_name=$(parse_field name "$file")
            fm_desc=$(parse_field description "$file")

            local shared_target="$SHARED_MEM/$name"

            if [ -e "$shared_target" ]; then
                echo "  ⚠️  shared already has '$name' — skipping (use interactive mode to overwrite/rename)" >&2
                return 1
            fi

            mv "$file" "$shared_target"
            remove_from_project_local "$proj_mem/MEMORY.md" "($name)"
            printf -- '- [%s](%s) — %s\n' "${fm_name:-$name}" "$name" "${fm_desc:-}" >> "$SHARED_MEM/MEMORY.md"
            bash "$script_self" sync >/dev/null 2>&1 || true
            echo "  → promoted to shared: $name"
            return 0
        }

        if [ "$BATCH_MODE" -eq 1 ]; then
            n_promoted=0
            n_skipped=0
            project_slug=$(basename "$(dirname "$proj_mem")")

            for bname in "${BATCH_FILES[@]}"; do
                bname=$(echo "$bname" | tr -d ' ')
                [ -z "$bname" ] && continue
                file="$proj_mem/$bname"
                if [ ! -f "$file" ]; then
                    echo "  skip: $bname (not found in project memory dir)"
                    n_skipped=$((n_skipped + 1))
                    continue
                fi
                if [ -L "$file" ]; then
                    echo "  skip: $bname (already a symlink — already in shared or already promoted)"
                    n_skipped=$((n_skipped + 1))
                    continue
                fi
                if promote_file "$file"; then
                    n_promoted=$((n_promoted + 1))
                else
                    n_skipped=$((n_skipped + 1))
                fi
            done

            echo ""
            echo "=== Batch promote summary ==="
            printf 'Promoted: %d  Skipped: %d\n' "$n_promoted" "$n_skipped"

            if [ "$n_promoted" -gt 0 ]; then
                shared_push "promote: batch from $project_slug"
            fi
            exit 0
        fi

        # Interactive mode
        # Collect real files (non-symlink, non-MEMORY.md)
        files=()
        for f in "$proj_mem"/*.md; do
            [ -e "$f" ] || continue
            bname=$(basename "$f")
            [ "$bname" = "MEMORY.md" ] && continue
            [ -L "$f" ] && continue
            files+=("$f")
        done

        if [ ${#files[@]} -eq 0 ]; then
            echo "No real files found in $proj_mem (all are symlinks or none exist)."
            echo "Run 'bash scripts/memory.sh list' to see current state."
            exit 0
        fi

        IFS=$'\n' files=($(printf '%s\n' "${files[@]}" | sort))
        unset IFS

        total=${#files[@]}
        n_promoted=0; n_kept=0; n_deleted=0; n_skipped=0
        promoted_names=()
        i=0
        project_slug=$(basename "$(dirname "$proj_mem")")

        for file in "${files[@]}"; do
            i=$((i + 1))
            name=$(basename "$file")

            fm_name=$(parse_field name "$file")
            fm_desc=$(parse_field description "$file")
            fm_type=$(parse_field type "$file")

            echo "---"
            printf '[%d/%d] %s\n' "$i" "$total" "$name"
            if [ -z "$fm_name" ] && [ -z "$fm_desc" ] && [ -z "$fm_type" ]; then
                echo "  (no frontmatter)"
            else
                [ -n "$fm_name" ]  && echo "  name: $fm_name"
                [ -n "$fm_desc" ]  && echo "  description: $fm_desc"
                [ -n "$fm_type" ]  && echo "  type: $fm_type"
            fi
            echo ""

            while true; do
                printf "Action? [p]romote / [k]eep / [d]elete / [s]kip / [q]uit: "
                ans=$(read_key)
                echo ""

                case "$ans" in
                    p|P)
                        shared_target="$SHARED_MEM/$name"
                        conflict=0
                        [ -e "$shared_target" ] && conflict=1

                        if [ "$conflict" -eq 1 ]; then
                            shared_fm_name=$(parse_field name "$shared_target" 2>/dev/null || true)
                            echo "⚠️  shared already has '$name':"
                            echo "    shared name: $shared_fm_name"
                            echo "    local name:  $fm_name"
                            while true; do
                                printf "Choose: [o]verwrite shared / [r]ename local / [c]ancel: "
                                conflict_ans=$(read_key)
                                echo ""
                                case "$conflict_ans" in
                                    o|O) break ;;
                                    r|R)
                                        printf "new name (without .md): "
                                        IFS= read -r new_base
                                        echo ""
                                        new_name="${new_base}.md"
                                        mv "$file" "$proj_mem/$new_name"
                                        file="$proj_mem/$new_name"
                                        name="$new_name"
                                        shared_target="$SHARED_MEM/$name"
                                        break
                                        ;;
                                    c|C)
                                        echo "  → cancelled."
                                        break 2
                                        ;;
                                    *) echo "  (invalid; expected o/r/c)" ;;
                                esac
                            done
                        fi

                        mv "$file" "$shared_target"
                        remove_from_project_local "$proj_mem/MEMORY.md" "($name)"
                        printf -- '- [%s](%s) — %s\n' "${fm_name:-$name}" "$name" "${fm_desc:-}" >> "$SHARED_MEM/MEMORY.md"
                        bash "$script_self" sync >/dev/null 2>&1 || true
                        echo "  → promoted to shared."
                        n_promoted=$((n_promoted + 1))
                        promoted_names+=("$name")
                        break
                        ;;
                    k|K)
                        echo "  → kept project-local."
                        n_kept=$((n_kept + 1))
                        break
                        ;;
                    d|D)
                        printf "  Confirm permanent delete of %s? [y/N]: " "$name"
                        confirm=$(read_key)
                        echo ""
                        case "$confirm" in
                            y|Y)
                                rm "$file"
                                remove_from_project_local "$proj_mem/MEMORY.md" "($name)"
                                echo "  → deleted."
                                n_deleted=$((n_deleted + 1))
                                ;;
                            *)
                                echo "  → cancelled."
                                ;;
                        esac
                        break
                        ;;
                    s|S)
                        echo "  → skipped (will appear next run)."
                        n_skipped=$((n_skipped + 1))
                        break
                        ;;
                    q|Q)
                        echo ""
                        echo "(quit)"
                        break 2
                        ;;
                    *)
                        echo "  (invalid; expected p/k/d/s/q)"
                        ;;
                esac
            done
        done

        echo ""
        echo "=== Summary ==="
        printf 'Promoted to shared: %d\n' "$n_promoted"
        printf 'Kept project-local: %d\n' "$n_kept"
        printf 'Deleted:            %d\n' "$n_deleted"
        printf 'Skipped:            %d\n' "$n_skipped"
        echo ""

        if [ "$n_promoted" -gt 0 ]; then
            shared_push "promote: ${promoted_names[*]} from $project_slug"
        fi

        echo "Run 'bash scripts/memory.sh list' to see current state."
        ;;
    help|--help|-h)
        sed -n '2,10p' "$0"
        ;;
    *)
        echo "unknown command: $cmd" >&2
        sed -n '2,9p' "$0" >&2
        exit 1
        ;;
esac
