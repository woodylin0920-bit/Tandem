#!/usr/bin/env bash
# Archive dated prompts under docs/prompts/_archive/<YYYY-MM>/
# Usage: bash scripts/archive-prompts.sh [--dry-run]
set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

cd "$(git rev-parse --show-toplevel)" || { echo "not in a git repo" >&2; exit 1; }
# shellcheck source=scripts/_paths.sh
source "$(dirname "$0")/_paths.sh"

STAGING="$TANDEM_LESSONS_STAGING"

# Detect lesson signals from an archive file. If detected, append raw entry to staging (idempotent by archive id).
detect_and_stage_lesson() {
    local archive_file="$1"
    local id
    id=$(basename "$archive_file" .md)

    [ "${DRY_RUN:-0}" = 1 ] && return 0
    [ -d "$(dirname "$STAGING")" ] || return 0

    if [ -f "$STAGING" ] && grep -q "^<!-- BEGIN entry id=$id " "$STAGING"; then
        return 0
    fi

    # Extract ## Result block content, skipping fenced code blocks
    local result_content
    result_content=$(awk '
        /^```/ {in_code = !in_code; next}
        in_code {next}
        /^## Result$/ {in_result=1; next}
        in_result && /^## / {in_result=0}
        in_result {print}
    ' "$archive_file")

    [ -z "$result_content" ] && return 0

    # Bug 1 fix: Status is "blocked" only when ❌ present and ✅ NOT present on same line
    local status_line has_blocked=""
    status_line=$(echo "$result_content" | grep -m1 -E '^(\*\*Status\*\*|Status):' || true)
    if [ -n "$status_line" ] && echo "$status_line" | grep -q "❌" && ! echo "$status_line" | grep -q "✅"; then
        has_blocked="$status_line"
    fi

    # Bug 3 fix: Blockers must be non-template (none / <description> / empty all skip)
    local has_blockers=""
    local blocker_line
    blocker_line=$(echo "$result_content" | grep -m1 -E '^\*\*Blockers\*\*:' || true)
    if [ -n "$blocker_line" ] && ! echo "$blocker_line" | grep -qiE 'none|<description>|^\*\*Blockers\*\*: *$'; then
        has_blockers="$blocker_line"
    fi

    # Bug 2 fix: FAIL only counts inside Result block, outside code fences, AND not on a "PASS / FAIL" template line
    # Bug 4 fix: restrict to ^- bullet lines; exclude negated "no FAIL" meta-text
    local has_fail=""
    local fail_line
    fail_line=$(echo "$result_content" | grep -E '^- .*\bFAIL\b' | grep -v 'PASS' | grep -viE '^- .*\bno\b.*\bFAIL\b' | head -1 || true)
    [ -n "$fail_line" ] && has_fail="$fail_line"

    # Keywords (also Result-block-scoped now); restrict to ^- bullet lines
    local has_keyword=""
    has_keyword=$(echo "$result_content" | grep -m1 -iE '^- .*(next time|should (have|do|run|abort)|lesson learned)' || true)

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
