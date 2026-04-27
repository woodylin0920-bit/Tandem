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
    ".claude/commands/resume.md|.claude/commands/resume.md"
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
        echo "[upgrade] WARN: target working tree is dirty (continuing anyway)"
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
    echo "Would overwrite (${#will_overwrite[@]}):"
    local x
    for x in "${will_overwrite[@]:-}"; do
        [ -z "$x" ] && continue
        rel="${x%%|*}"
        local rest="${x#*|}"
        local hint="${rest##*|}"
        printf "  %-44s [%s]\n" "$rel" "$hint"
    done
    echo ""

    echo "Would merge .claude/settings.json:"
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
            echo "  $rel"
            echo "    → diff: diff $d $s"
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
    n_written=$((n_written + 1))

    echo "Done. $n_written files written. Run 'git -C $target diff' to inspect."
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
        echo "ERROR: --remove not implemented yet" >&2
        exit 1
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
cp "$HARNESS_DIR/.claude/commands/resume.md" .claude/commands/
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
mkdir -p "$MEM_DIR"
cp "$HARNESS_DIR/templates/memory/MEMORY.md" "$MEM_DIR/MEMORY.md"
cp "$HARNESS_DIR/templates/memory/feedback_terse_zh.md" "$MEM_DIR/"
cp "$HARNESS_DIR/templates/memory/feedback_workflow_split.md" "$MEM_DIR/"
cp "$HARNESS_DIR/templates/memory/feedback_model_split.md" "$MEM_DIR/"
cp "$HARNESS_DIR/templates/memory/env_paths.md" "$MEM_DIR/"

# Substitute project name placeholder in memory files
sed -i '' "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$MEM_DIR"/env_paths.md 2>/dev/null || true

# git init
git init -q
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
