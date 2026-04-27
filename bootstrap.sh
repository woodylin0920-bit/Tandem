#!/usr/bin/env bash
# woody-harness bootstrap — create new project, upgrade, or remove framework.
# Usage:
#   bash bootstrap.sh <project-name>                          # create new project
#   bash bootstrap.sh --upgrade-existing <path> [--apply]     # upgrade existing project
#   bash bootstrap.sh --remove <path> [--apply]               # remove framework cleanly
set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"

# -----------------------------------------------------------------------------
# Framework file inventory (single source of truth for upgrade + remove).
# Each entry: "<target-relative-path>|<harness-source-relative-path>"
# -----------------------------------------------------------------------------
FRAMEWORK_FILES=(
    ".claude/commands/inbox.md|.claude/commands/inbox.md"
    ".claude/commands/brief.md|.claude/commands/brief.md"
    ".claude/commands/sync.md|.claude/commands/sync.md"
    ".claude/commands/codex-audit.md|.claude/commands/codex-audit.md"
    ".claude/commands/phase-gate.md|.claude/commands/phase-gate.md"
    "scripts/archive-prompts.sh|scripts/archive-prompts.sh"
    "scripts/memory.sh|scripts/memory.sh"
    "scripts/statusline.sh|scripts/statusline.sh"
    "scripts/session-briefing.sh|scripts/session-briefing.sh"
    "scripts/notify-blocked.sh|scripts/notify-blocked.sh"
)

# Hash-compared files: pristine → upgrade overwrites / remove deletes;
# user-modified → both modes skip with diff hint.
SKIP_IF_MODIFIED_FILES=(
    "docs/prompts/README.md|templates/prompts/README.md"
)

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
file_hash() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

diff_stats() {
    local a="$1" b="$2" added removed
    added=$(diff "$a" "$b" 2>/dev/null | grep -c '^>' || true)
    removed=$(diff "$a" "$b" 2>/dev/null | grep -c '^<' || true)
    echo "+${added} -${removed}"
}

validate_json() {
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$1" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Upgrade mode
# -----------------------------------------------------------------------------
merge_settings_json() {
    # $1 target settings (may not exist), $2 framework settings, $3 output path
    local target_settings="$1" fw_settings="$2" out="$3"
    if [ ! -f "$target_settings" ]; then
        cp "$fw_settings" "$out"
        return
    fi
    jq -s '
      .[0] as $target | .[1] as $fw |
      ($target * $fw) |
      .permissions.allow = (($target.permissions.allow // []) + ($fw.permissions.allow // []) | unique) |
      .hooks.SessionStart = (($target.hooks.SessionStart // []) + ($fw.hooks.SessionStart // []) | unique_by(.hooks[0].command)) |
      .hooks.Notification = (($target.hooks.Notification // []) + ($fw.hooks.Notification // []) | unique_by(.hooks[0].command)) |
      .statusLine = ($target.statusLine // $fw.statusLine)
    ' "$target_settings" "$fw_settings" > "$out"
}

upgrade_preflight() {
    local target="$1"
    [ -d "$target" ] || { echo "ERROR: $target does not exist" >&2; exit 1; }
    [ -d "$target/.git" ] || { echo "ERROR: $target is not a git repo (run 'git init' first)" >&2; exit 1; }
    [ -f "$target/.claude/commands/inbox.md" ] || {
        echo "ERROR: This doesn't look like a woody-harness project. Run 'bash bootstrap.sh <name>' first." >&2
        exit 1
    }
    if ! git -C "$target" diff-index --quiet HEAD -- 2>/dev/null; then
        echo ""
        echo "⚠️  WARNING: target working tree is dirty"
        echo "   Continuing — your existing changes will mix with upgrade changes."
        echo "   Consider 'git stash' first, or commit existing changes, before re-running."
        echo ""
    fi
}

upgrade_existing() {
    local target apply
    target="$(cd "$1" && pwd)"
    apply="${2:-}"

    upgrade_preflight "$target"

    echo "[upgrade] Target: $target"
    echo "[upgrade] Framework: $HARNESS_DIR"
    echo ""

    local will_overwrite=()  # entries: rel|src|hint
    local will_uptodate=()
    local will_skip=()       # entries: rel|src|dst

    local entry rel src_rel src dst h_src h_dst stats
    for entry in "${FRAMEWORK_FILES[@]}"; do
        rel="${entry%%|*}"
        src_rel="${entry##*|}"
        src="$HARNESS_DIR/$src_rel"
        dst="$target/$rel"
        if [ ! -f "$dst" ]; then
            will_overwrite+=("$rel|$src|new file")
        else
            h_src=$(file_hash "$src")
            h_dst=$(file_hash "$dst")
            if [ "$h_src" = "$h_dst" ]; then
                will_uptodate+=("$rel")
            else
                stats=$(diff_stats "$dst" "$src")
                will_overwrite+=("$rel|$src|diff: $stats")
            fi
        fi
    done

    for entry in "${SKIP_IF_MODIFIED_FILES[@]}"; do
        rel="${entry%%|*}"
        src_rel="${entry##*|}"
        src="$HARNESS_DIR/$src_rel"
        dst="$target/$rel"
        if [ ! -f "$dst" ]; then
            will_overwrite+=("$rel|$src|new file")
        else
            h_src=$(file_hash "$src")
            h_dst=$(file_hash "$dst")
            if [ "$h_src" = "$h_dst" ]; then
                will_uptodate+=("$rel")
            else
                will_skip+=("$rel|$src|$dst")
            fi
        fi
    done

    # settings.json merge analysis
    local fw_settings="$HARNESS_DIR/.claude/settings.json"
    local target_settings="$target/.claude/settings.json"
    local merged_tmp
    merged_tmp=$(mktemp)
    merge_settings_json "$target_settings" "$fw_settings" "$merged_tmp"
    if ! validate_json "$merged_tmp"; then
        rm -f "$merged_tmp"
        echo "ERROR: settings.json merge produced invalid JSON — aborting" >&2
        exit 1
    fi

    # Print plan
    if [ "$apply" = "--apply" ]; then
        echo "Overwriting (${#will_overwrite[@]}):"
    else
        echo "Would overwrite (${#will_overwrite[@]}):"
    fi
    local x
    for x in "${will_overwrite[@]:-}"; do
        [ -z "$x" ] && continue
        rel="${x%%|*}"
        local rest="${x#*|}"
        local hint="${rest##*|}"
        printf "  %-44s [%s]\n" "$rel" "$hint"
    done
    echo ""

    if [ "$apply" = "--apply" ]; then
        echo "Merging .claude/settings.json:"
    else
        echo "Would merge .claude/settings.json:"
    fi
    if [ -f "$target_settings" ]; then
        local new_perms
        new_perms=$(jq -r --slurpfile fw "$fw_settings" --slurpfile tgt "$target_settings" \
            -n '($fw[0].permissions.allow // []) - ($tgt[0].permissions.allow // []) | .[]' 2>/dev/null || true)
        if [ -n "$new_perms" ]; then
            echo "  + permissions.allow new entries:"
            echo "$new_perms" | sed 's/^/      /'
        else
            echo "  = permissions.allow up-to-date"
        fi
        # statusLine
        local tgt_sl fw_sl
        tgt_sl=$(jq -c '.statusLine // null' "$target_settings")
        fw_sl=$(jq -c '.statusLine // null' "$fw_settings")
        if [ "$tgt_sl" = "null" ] && [ "$fw_sl" != "null" ]; then
            echo "  + statusLine (target had none, adding framework's)"
        else
            echo "  = statusLine kept (target's wins)"
        fi
    else
        echo "  + new settings.json (target had none)"
    fi
    echo ""

    if [ ${#will_skip[@]} -gt 0 ]; then
        echo "Skipped — user-modified (${#will_skip[@]}):"
        for x in "${will_skip[@]}"; do
            rel="${x%%|*}"
            local rest="${x#*|}"
            local s="${rest%%|*}"
            local d="${rest##*|}"
            local short_s short_d
            short_s=$(echo "$s" | sed "s|$HOME|~|")
            short_d=$(echo "$d" | sed "s|$HOME|~|")
            echo "  $rel"
            echo "    → diff: diff $short_d $short_s"
        done
        echo ""
    fi

    if [ ${#will_uptodate[@]} -gt 0 ]; then
        echo "Up-to-date (${#will_uptodate[@]}):"
        for x in "${will_uptodate[@]}"; do echo "  $x"; done
        echo ""
    fi

    if [ "$apply" != "--apply" ]; then
        rm -f "$merged_tmp"
        echo "Run with --apply to actually write changes."
        return 0
    fi

    # Apply
    local n_written=0
    local settings_merged=false
    for x in "${will_overwrite[@]:-}"; do
        [ -z "$x" ] && continue
        rel="${x%%|*}"
        local rest="${x#*|}"
        local s="${rest%%|*}"
        dst="$target/$rel"
        mkdir -p "$(dirname "$dst")"
        cp "$s" "$dst"
        n_written=$((n_written + 1))
    done

    mkdir -p "$(dirname "$target_settings")"
    cp "$merged_tmp" "$target_settings"
    rm -f "$merged_tmp"
    settings_merged=true

    # Build summary based on what actually happened
    local parts=()
    if [ "$n_written" -gt 0 ]; then
        local _s=""
        [ "$n_written" -ne 1 ] && _s="s" || true
        parts+=("$n_written file${_s} written")
    fi
    [ "$settings_merged" = "true" ] && parts+=("settings.json merged") || true
    local summary
    if [ "${#parts[@]}" -gt 0 ]; then
        summary=$(IFS=", "; echo "${parts[*]}")
    else
        summary="no changes"
    fi

    echo ""
    echo "Done. $summary."
    echo "Run 'git -C $target status' to see all new/modified files,"
    echo "then 'git -C $target diff' for content of modified files."
}

# -----------------------------------------------------------------------------
# Remove mode
# -----------------------------------------------------------------------------
reverse_merge_settings_json() {
    # $1 target settings, $2 framework settings, $3 output path.
    # Returns 0 if output written, 1 if target settings doesn't exist.
    local target_settings="$1" fw_settings="$2" out="$3"
    [ -f "$target_settings" ] || return 1
    jq -s '
      .[0] as $target | .[1] as $fw |
      $target |
      .permissions.allow = (($target.permissions.allow // []) - ($fw.permissions.allow // [])) |
      .hooks.SessionStart = ([($target.hooks.SessionStart // [])[] | .hooks |= map(select(.command != ($fw.hooks.SessionStart[0].hooks[0].command // "__nope__")))] | map(select(.hooks | length > 0))) |
      .hooks.Notification = ([($target.hooks.Notification // [])[] | .hooks |= map(select(.command != ($fw.hooks.Notification[0].hooks[0].command // "__nope__")))] | map(select(.hooks | length > 0))) |
      (if .statusLine == $fw.statusLine then del(.statusLine) else . end) |
      (if (.hooks.SessionStart // [] | length) == 0 then del(.hooks.SessionStart) else . end) |
      (if (.hooks.Notification // [] | length) == 0 then del(.hooks.Notification) else . end) |
      (if (.hooks // {}) == {} then del(.hooks) else . end) |
      (if (.permissions.allow // [] | length) == 0 then del(.permissions.allow) else . end) |
      (if (.permissions // {}) == {} then del(.permissions) else . end)
    ' "$target_settings" "$fw_settings" > "$out"
    return 0
}

remove_preflight() {
    local target="$1"
    [ -d "$target" ] || { echo "ERROR: $target does not exist" >&2; exit 1; }
    [ -f "$target/.claude/commands/inbox.md" ] || {
        echo "ERROR: Not a woody-harness project, nothing to remove." >&2
        exit 1
    }
}

remove_harness() {
    local target apply
    target="$(cd "$1" && pwd)"
    apply="${2:-}"

    remove_preflight "$target"

    echo "[remove] Target: $target"
    echo ""

    local will_delete=()       # entries: rel
    local will_skip=()         # entries: rel|src|dst (user-modified, kept)
    local entry rel src_rel src dst h_src h_dst

    for entry in "${FRAMEWORK_FILES[@]}"; do
        rel="${entry%%|*}"
        dst="$target/$rel"
        [ -f "$dst" ] && will_delete+=("$rel")
    done

    # _inbox.md always deleted (per spec — user must handle queued prompt before remove)
    if [ -f "$target/docs/prompts/_inbox.md" ]; then
        will_delete+=("docs/prompts/_inbox.md")
    fi

    # Skip-if-modified: delete only if pristine
    for entry in "${SKIP_IF_MODIFIED_FILES[@]}"; do
        rel="${entry%%|*}"
        src_rel="${entry##*|}"
        src="$HARNESS_DIR/$src_rel"
        dst="$target/$rel"
        [ -f "$dst" ] || continue
        h_src=$(file_hash "$src")
        h_dst=$(file_hash "$dst")
        if [ "$h_src" = "$h_dst" ]; then
            will_delete+=("$rel")
        else
            will_skip+=("$rel|$src|$dst")
        fi
    done

    # Reverse-merge settings.json analysis
    local fw_settings="$HARNESS_DIR/.claude/settings.json"
    local target_settings="$target/.claude/settings.json"
    local merged_tmp settings_action settings_result_summary
    merged_tmp=$(mktemp)
    settings_action=""        # "delete" | "rewrite" | "none"
    settings_result_summary=""

    if [ -f "$target_settings" ]; then
        if reverse_merge_settings_json "$target_settings" "$fw_settings" "$merged_tmp"; then
            if ! validate_json "$merged_tmp"; then
                rm -f "$merged_tmp"
                echo "ERROR: settings.json reverse-merge produced invalid JSON — aborting" >&2
                exit 1
            fi
            local result_compact
            result_compact=$(jq -c '.' "$merged_tmp")
            if [ "$result_compact" = "{}" ]; then
                settings_action="delete"
                settings_result_summary="empty after strip → file will be removed"
            else
                settings_action="rewrite"
                settings_result_summary="$result_compact"
            fi
        fi
    else
        settings_action="none"
        settings_result_summary="(no target settings.json)"
    fi

    # Slug for memory dir hint
    local slug mem_dir
    slug=$(echo "$target" | sed 's|/|-|g')
    mem_dir="$HOME/.claude-work/projects/$slug"

    # Print plan
    if [ "$apply" = "--apply" ]; then
        echo "Deleting (${#will_delete[@]} files):"
    else
        echo "Would delete (${#will_delete[@]} files):"
    fi
    local x
    for x in "${will_delete[@]:-}"; do
        [ -z "$x" ] && continue
        echo "  $x"
    done
    echo ""

    if [ "$apply" = "--apply" ]; then
        echo "Reversing-merge .claude/settings.json:"
    else
        echo "Would reverse-merge .claude/settings.json:"
    fi
    case "$settings_action" in
        delete)   echo "  → $settings_result_summary" ;;
        rewrite)  echo "  → result: $settings_result_summary" ;;
        none)     echo "  $settings_result_summary" ;;
    esac
    echo ""

    if [ ${#will_skip[@]} -gt 0 ]; then
        echo "Skipped — user-modified (${#will_skip[@]}):"
        for x in "${will_skip[@]}"; do
            rel="${x%%|*}"
            local rest="${x#*|}"
            local s="${rest%%|*}"
            local d="${rest##*|}"
            local short_s short_d
            short_s=$(echo "$s" | sed "s|$HOME|~|")
            short_d=$(echo "$d" | sed "s|$HOME|~|")
            echo "  $rel   [hash differs from framework, kept as-is]"
            echo "    → diff: diff $short_d $short_s"
        done
        echo ""
    fi

    if [ "$apply" = "--apply" ]; then
        echo "Removing empty dirs (if any):"
    else
        echo "Would remove empty dirs (if any):"
    fi
    echo "  scripts/, .claude/commands/, .claude/"
    echo ""

    if [ "$apply" = "--apply" ]; then
        echo "NOT touching:"
    else
        echo "Would NOT touch:"
    fi
    echo "  CLAUDE.md, RESUME.md, .gitignore"
    echo "  docs/prompts/_archive/  (your prompt history)"
    echo "  $mem_dir/  (your memory — preserved)"
    echo ""

    echo "Memory dir location (run manually if you want it gone):"
    echo "  rm -rf $mem_dir"
    echo ""

    if [ "$apply" != "--apply" ]; then
        rm -f "$merged_tmp"
        echo "Run with --apply to actually delete."
        return 0
    fi

    # Apply
    local n_deleted=0
    for x in "${will_delete[@]:-}"; do
        [ -z "$x" ] && continue
        dst="$target/$x"
        if [ -f "$dst" ]; then
            rm -f "$dst"
            n_deleted=$((n_deleted + 1))
        fi
    done

    case "$settings_action" in
        delete)
            rm -f "$target_settings"
            ;;
        rewrite)
            cp "$merged_tmp" "$target_settings"
            ;;
    esac
    rm -f "$merged_tmp"

    # Empty dir cleanup (rmdir fails silently on non-empty)
    rmdir "$target/scripts" 2>/dev/null || true
    rmdir "$target/.claude/commands" 2>/dev/null || true
    rmdir "$target/.claude" 2>/dev/null || true

    echo ""
    echo "Done. $n_deleted files deleted. Memory preserved at $mem_dir/."
    echo "Run 'git -C $target status' to see deleted files before committing."
}

# -----------------------------------------------------------------------------
# Main dispatcher
# -----------------------------------------------------------------------------
MODE="${1:-}"
case "$MODE" in
    --upgrade-existing)
        shift
        [ $# -ge 1 ] || { echo "Usage: bash bootstrap.sh --upgrade-existing <path> [--apply]" >&2; exit 1; }
        TARGET_ARG="$1"; shift
        APPLY_ARG="${1:-}"
        upgrade_existing "$TARGET_ARG" "$APPLY_ARG"
        exit 0
        ;;
    --remove)
        shift
        [ $# -ge 1 ] || { echo "Usage: bash bootstrap.sh --remove <path> [--apply]" >&2; exit 1; }
        TARGET_ARG="$1"; shift
        APPLY_ARG="${1:-}"
        remove_harness "$TARGET_ARG" "$APPLY_ARG"
        exit 0
        ;;
    "")
        echo "Usage:"
        echo "  bash bootstrap.sh <project-name>                          # create new project"
        echo "  bash bootstrap.sh --upgrade-existing <path> [--apply]     # upgrade existing"
        echo "  bash bootstrap.sh --remove <path> [--apply]               # remove framework"
        exit 1
        ;;
    -*)
        echo "ERROR: unknown flag: $MODE" >&2
        exit 1
        ;;
    *)
        # fall through to new-project flow
        ;;
esac

# -----------------------------------------------------------------------------
# New-project flow (original behavior)
# -----------------------------------------------------------------------------
PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

if [ -e "$PROJECT_DIR" ]; then
    echo "ERROR: $PROJECT_DIR already exists"
    exit 1
fi

echo "[bootstrap] Creating $PROJECT_DIR..."
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Copy templates
mkdir -p .claude/commands docs/prompts
# Copy all slash commands + settings
cp "$HARNESS_DIR/.claude/commands/inbox.md" .claude/commands/
cp "$HARNESS_DIR/.claude/commands/brief.md" .claude/commands/
cp "$HARNESS_DIR/.claude/commands/phase-gate.md" .claude/commands/
cp "$HARNESS_DIR/.claude/commands/codex-audit.md" .claude/commands/
cp "$HARNESS_DIR/.claude/settings.json" .claude/settings.json
cp "$HARNESS_DIR/templates/CLAUDE.md" CLAUDE.md
cp "$HARNESS_DIR/templates/RESUME.md" RESUME.md
cp "$HARNESS_DIR/templates/.gitignore" .gitignore
cp "$HARNESS_DIR/templates/prompts/_inbox.md" docs/prompts/_inbox.md
cp "$HARNESS_DIR/templates/prompts/README.md" docs/prompts/README.md

# Copy archive helper
mkdir -p scripts
cp "$HARNESS_DIR/scripts/archive-prompts.sh" scripts/archive-prompts.sh
cp "$HARNESS_DIR/scripts/memory.sh" scripts/memory.sh
cp "$HARNESS_DIR/scripts/statusline.sh" scripts/statusline.sh
cp "$HARNESS_DIR/scripts/session-briefing.sh" scripts/session-briefing.sh
cp "$HARNESS_DIR/scripts/notify-blocked.sh" scripts/notify-blocked.sh
cp "$HARNESS_DIR/.claude/commands/sync.md" .claude/commands/

# Substitute project name placeholder
sed -i '' "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" CLAUDE.md RESUME.md 2>/dev/null || true

# Setup memory directory
SLUG=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
MEM_DIR="$HOME/.claude-work/projects/$SLUG/memory"
SHARED_MEM="$HOME/.claude-work/_shared/memory"

SHARED_SEEDS=(feedback_terse_zh.md feedback_workflow_split.md feedback_model_split.md)
PROJECT_SEEDS=(env_paths.md)

# 1. First bootstrap: seed _shared/ (skip if already exists)
if [ ! -d "$SHARED_MEM" ]; then
    mkdir -p "$SHARED_MEM"
    for f in "${SHARED_SEEDS[@]}"; do
        cp "$HARNESS_DIR/templates/memory/$f" "$SHARED_MEM/"
    done
    cat > "$SHARED_MEM/MEMORY.md" <<'EOF'
- [terse Mandarin updates](feedback_terse_zh.md) — reply in 繁中, 1-2 sentences, mid-task pings = status check not stop
- [planning-here, execute-elsewhere workflow](feedback_workflow_split.md) — this window plans + writes prompts; user runs them via /inbox in separate Sonnet session.
- [model split: Opus plans, Sonnet executes](feedback_model_split.md) — terminal=Opus 4.7 (planning), terminal=Sonnet (executor). Make execution prompts very explicit.
EOF
    echo "[bootstrap] Seeded shared memory at $SHARED_MEM (first time)"
fi

# 2. Project memory dir: only project-specific files
mkdir -p "$MEM_DIR"
for f in "${PROJECT_SEEDS[@]}"; do
    cp "$HARNESS_DIR/templates/memory/$f" "$MEM_DIR/"
done
sed -i '' "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$MEM_DIR"/env_paths.md 2>/dev/null || true

# 3. Initial project MEMORY.md with markers + project-local seed entry
cat > "$MEM_DIR/MEMORY.md" <<'EOF'
<!-- BEGIN shared (auto-managed by scripts/memory.sh sync — do not edit between markers) -->
<!-- END shared -->

<!-- BEGIN project-local (you can edit this section freely) -->
- [environment paths](env_paths.md) — bash + markdown only (no venv); macOS BSD sed quirks
<!-- END project-local -->
EOF

# git init
git init -q

# 4. Sync shared layer into project memory (needs git to be initialized)
bash scripts/memory.sh sync >/dev/null 2>&1 || echo "[bootstrap] WARN: memory sync failed (run 'bash scripts/memory.sh sync' manually)"

git add .
git commit -q -m "chore: bootstrap from woody-harness"

# Sanity check — RESUME.md is required for SessionStart briefing
test -f RESUME.md || { echo "[bootstrap] WARN: RESUME.md missing — SessionStart briefing will be silent" >&2; }

echo "[bootstrap] Done."
echo ""
echo "Next steps:"
echo "  cd $PROJECT_NAME"
echo "  # Terminal 1 (planning):"
echo "  claude   # Opus"
echo "  # Terminal 2 (execution):"
echo "  claude --model sonnet"
echo "  # In Sonnet session: /inbox after Opus writes a prompt"
echo ""
echo "Memory dir: $MEM_DIR"
