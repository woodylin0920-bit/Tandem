#!/usr/bin/env bash
# lessons.sh — auto-extracted lesson candidates from archive flow.
# State machine: raw (appended by archive-prompts.sh) → candidate (refined by `extract`) → promoted/deleted (by `review`).
# Usage:
#   bash scripts/lessons.sh count             # how many entries pending (any state)
#   bash scripts/lessons.sh list              # list all entries with state
#   bash scripts/lessons.sh extract           # raw → candidate via headless claude
#   bash scripts/lessons.sh review            # candidate → promoted (shared memory) / deleted (interactive)
set -euo pipefail

SHARED_DIR="$HOME/.claude-work/shared"
STAGING="$HOME/.claude-work/shared/lessons-staging.md"
SHARED_MEM="$HOME/.claude-work/shared/memory"
SHARED_LESSONS="$HOME/.claude-work/shared/lessons"

cmd="${1:-help}"

ensure_staging() {
    mkdir -p "$SHARED_DIR/lessons" "$SHARED_MEM"
    [ -f "$STAGING" ] || : > "$STAGING"
}

shared_lessons_push() {
    local slug="$1"
    local orig_dir="$PWD"
    if [ ! -d "$SHARED_DIR/.git" ]; then
        echo "  WARN: $SHARED_DIR is not a git repo — skipping shared lessons push" >&2
        return 0
    fi
    cd "$SHARED_DIR"
    git add -A
    if git diff --cached --quiet; then
        cd "$orig_dir"
        return 0
    fi
    git commit -m "lesson: $slug"
    if ! git push 2>&1; then
        echo "error: git push to shared remote failed" >&2
        echo "  Check: cd $SHARED_DIR && git push" >&2
        cd "$orig_dir"
        exit 1
    fi
    cd "$orig_dir"
}

count_entries() {
    local state="${1:-}"
    [ -f "$STAGING" ] || { echo 0; return; }
    if [ -z "$state" ]; then
        grep -c '^<!-- BEGIN entry ' "$STAGING" 2>/dev/null || echo 0
    else
        grep -c "^<!-- BEGIN entry .*state=$state" "$STAGING" 2>/dev/null || echo 0
    fi
}

list_entries() {
    [ -f "$STAGING" ] || { echo "(no staging file yet)"; return; }
    awk '/^<!-- BEGIN entry/ {
        id = $0; sub(/.*id=/, "", id); sub(/ .*/, "", id)
        st = $0; sub(/.*state=/, "", st); sub(/ .*/, "", st)
        printf "  %s  state=%s\n", id, st
    }' "$STAGING"
}

# Read full entry block by id
read_entry() {
    local id="$1"
    awk -v id="$id" '
        $0 ~ "^<!-- BEGIN entry id="id" " {grab=1}
        grab {print}
        $0 == "<!-- END entry -->" && grab {grab=0; exit}
    ' "$STAGING"
}

# Remove entry block by id
remove_entry() {
    local id="$1"
    local tmp
    tmp=$(mktemp)
    awk -v id="$id" '
        $0 ~ "^<!-- BEGIN entry id="id" " {skip=1; next}
        skip && $0 == "<!-- END entry -->" {skip=0; next}
        !skip {print}
    ' "$STAGING" > "$tmp"
    mv "$tmp" "$STAGING"
}

# List ids by state
ids_with_state() {
    local state="$1"
    [ -f "$STAGING" ] || return
    awk -v st="$state" '
        $0 ~ "^<!-- BEGIN entry " && $0 ~ "state="st {
            id = $0; sub(/.*id=/, "", id); sub(/ .*/, "", id)
            print id
        }
    ' "$STAGING"
}

# Replace entry by id with new content (multi-line). new_content already includes BEGIN/END markers.
replace_entry() {
    local id="$1"
    local new_content="$2"
    local tmp newfile
    tmp=$(mktemp)
    newfile=$(mktemp)
    printf '%s\n' "$new_content" > "$newfile"
    awk -v id="$id" -v newfile="$newfile" '
        $0 ~ "^<!-- BEGIN entry id="id" " {
            while ((getline line < newfile) > 0) print line
            close(newfile)
            skip=1; next
        }
        skip && $0 == "<!-- END entry -->" {skip=0; next}
        !skip {print}
    ' "$STAGING" > "$tmp"
    mv "$tmp" "$STAGING"
    rm -f "$newfile"
}

# Read a single key without echo (for prompts)
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

case "$cmd" in
    help|--help|-h)
        cat <<'HELP'
lessons.sh — auto-extracted lesson candidates from archive flow.

Subcommands:
  count             pending entries (all states)
  list              list entries with state
  extract           refine raw entries into candidates via headless claude
  review            interactive promote/delete on candidates (default = shared)

Staging: ~/.claude-work/_shared/lessons-staging.md
HELP
        ;;
    count)
        ensure_staging
        n=$(count_entries)
        n_raw=$(count_entries raw)
        n_cand=$(count_entries candidate)
        echo "$n total ($n_raw raw, $n_cand candidate)"
        ;;
    list)
        ensure_staging
        n=$(count_entries)
        if [ "$n" = 0 ]; then
            echo "(no entries — staging clean)"
        else
            echo "$n entries:"
            list_entries
        fi
        ;;
    extract)
        ensure_staging
        ids=$(ids_with_state raw)
        if [ -z "$ids" ]; then
            echo "(no raw entries to extract — staging clean or all already candidates)"
            exit 0
        fi
        if ! command -v claude >/dev/null 2>&1; then
            echo "WARN: 'claude' CLI not found in PATH — extract step needs it" >&2
            echo "Fallback: paste raw entries below into your planner Opus session manually:" >&2
            for id in $ids; do
                echo ""
                echo "--- raw entry: $id ---"
                read_entry "$id"
            done
            exit 1
        fi
        for id in $ids; do
            echo "Extracting: $id"
            raw_block=$(read_entry "$id")
            prompt=$(cat <<EOF
You are extracting a feedback lesson from a Tandem inbox archive that hit problems mid-run.

Read the raw signals below and produce a single feedback memory entry that:
- Has a short evocative name (under 60 chars)
- Has a one-line description capturing the rule
- Body has two sections: '**Why:**' (root cause / motivation) and '**How to apply:**' (concrete future actions)
- Stays under 200 words total

Output ONLY the markdown body (frontmatter + body). Do not include BEGIN/END markers, do not include explanation.

Frontmatter format:
\`\`\`
---
name: <name>
description: <description>
type: feedback
source-archive: <archive path from raw>
---

<body>
\`\`\`

Raw signals:
$raw_block
EOF
)
            refined=$(claude -p "$prompt" 2>/dev/null) || {
                echo "  ERROR: claude CLI failed for $id — leaving as raw" >&2
                continue
            }
            ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            new_entry="<!-- BEGIN entry id=$id state=candidate timestamp=$ts -->
$refined
<!-- END entry -->"
            replace_entry "$id" "$new_entry"
            echo "  → candidate ready"
        done
        echo ""
        echo "Done. Run 'bash scripts/lessons.sh review' to promote/delete."
        ;;
    review)
        ensure_staging
        ids=$(ids_with_state candidate)
        if [ -z "$ids" ]; then
            echo "(no candidates to review — run 'lessons.sh extract' first if you have raw entries)"
            exit 0
        fi
        n_promoted=0; n_deleted=0; n_skipped=0
        total=$(echo "$ids" | wc -l | tr -d ' ')
        i=0
        for id in $ids; do
            i=$((i + 1))
            echo "---"
            printf '[%d/%d] %s\n' "$i" "$total" "$id"
            block=$(read_entry "$id")
            # Print frontmatter + body (strip BEGIN/END markers)
            echo "$block" | sed '1d;$d'
            echo ""
            while true; do
                printf "Action? [p]romote-shared / [d]elete / [s]kip / [q]uit: "
                ans=$(read_key)
                echo ""
                case "$ans" in
                    p|P|"")
                        # Extract slug from frontmatter name
                        slug=$(echo "$block" | awk '/^name:/ {sub(/^name:[ \t]*/, ""); gsub(/[^a-zA-Z0-9]/, "_"); print tolower($0); exit}')
                        if [ -z "$slug" ]; then
                            slug="lesson_$(date +%s)"
                        fi
                        shared_lessons_target="$SHARED_LESSONS/${slug}.md"
                        target="$SHARED_MEM/${slug}.md"
                        if [ -e "$target" ] || [ -e "$shared_lessons_target" ]; then
                            printf "  ⚠️  %s exists. [o]verwrite / [c]ancel: " "$slug"
                            cans=$(read_key); echo ""
                            case "$cans" in
                                o|O) ;;
                                *) echo "  → cancelled (kept as candidate)"; break ;;
                            esac
                        fi
                        # Write to shared/lessons/ (canonical location)
                        mkdir -p "$SHARED_LESSONS"
                        echo "$block" | sed '1d;$d' > "$shared_lessons_target"
                        # Also copy to shared/memory/ for immediate memory linking
                        cp "$shared_lessons_target" "$target"
                        # Append index to shared MEMORY.md
                        name=$(awk '/^name:/ {sub(/^name:[ \t]*/, ""); print; exit}' "$target")
                        desc=$(awk '/^description:/ {sub(/^description:[ \t]*/, ""); print; exit}' "$target")
                        printf -- '- [%s](%s) — %s\n' "${name:-$slug}" "${slug}.md" "${desc:-}" >> "$SHARED_MEM/MEMORY.md"
                        remove_entry "$id"
                        echo "  → promoted: lessons/$slug.md + memory/$slug.md"
                        n_promoted=$((n_promoted + 1))
                        # Push to shared remote
                        shared_lessons_push "$slug"
                        break
                        ;;
                    d|D)
                        printf "  Confirm delete? [y/N]: "
                        confirm=$(read_key); echo ""
                        case "$confirm" in
                            y|Y) remove_entry "$id"; echo "  → deleted"; n_deleted=$((n_deleted + 1)); break ;;
                            *) echo "  → cancelled" ;;
                        esac
                        ;;
                    s|S) echo "  → skipped"; n_skipped=$((n_skipped + 1)); break ;;
                    q|Q) echo "(quit)"; break 2 ;;
                    *) echo "  (invalid)" ;;
                esac
            done
        done
        echo ""
        echo "=== Summary ==="
        printf 'Promoted: %d  Deleted: %d  Skipped: %d\n' "$n_promoted" "$n_deleted" "$n_skipped"
        ;;
    *)
        echo "Unknown subcommand: $cmd" >&2
        echo "Run 'bash scripts/lessons.sh help' for usage." >&2
        exit 1
        ;;
esac
