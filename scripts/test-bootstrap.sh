#!/usr/bin/env bash
# Smoke test for bootstrap.sh — verify a fresh bootstrap produces a working project.
# Run from harness repo root: bash scripts/test-bootstrap.sh
# Exits 0 on pass, 1 on any failure. Cleans up test project + memory dir on exit.
# 36 assertions total.
set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_NAME="wh-bootstrap-test-$$"
TEST_DIR="/tmp/$TEST_NAME"
TEST_SLUG=$(echo "$TEST_DIR" | sed 's|/|-|g')
MEM_DIR="$HOME/.claude-work/projects/$TEST_SLUG/memory"

cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
    rm -rf "$HOME/.claude-work/projects/$TEST_SLUG" 2>/dev/null || true
}
trap cleanup EXIT

fail=0
pass=0
assert() {
    local label="$1"
    shift
    if eval "$@" >/dev/null 2>&1; then
        echo "  ✅ $label"
        pass=$((pass + 1))
    else
        echo "  ❌ $label" >&2
        fail=$((fail + 1))
    fi
}

cd /tmp
rm -rf "$TEST_DIR"
echo "=== Running: bash $HARNESS_DIR/bootstrap.sh $TEST_NAME ==="
bash "$HARNESS_DIR/bootstrap.sh" "$TEST_NAME" >/dev/null
cd "$TEST_DIR"

echo ""
echo "=== File presence (15 files) ==="
assert "CLAUDE.md exists"                  test -f CLAUDE.md
assert "RESUME.md exists"                  test -f RESUME.md
assert ".gitignore exists"                 test -f .gitignore
assert ".claude/settings.json exists"      test -f .claude/settings.json
assert ".claude/commands/inbox.md exists"  test -f .claude/commands/inbox.md
assert ".claude/commands/brief.md exists" test -f .claude/commands/brief.md
assert ".claude/commands/phase-gate.md exists"  test -f .claude/commands/phase-gate.md
assert ".claude/commands/codex-audit.md exists" test -f .claude/commands/codex-audit.md
assert ".claude/commands/sync.md exists"        test -f .claude/commands/sync.md
assert "docs/prompts/_inbox.md exists"     test -f docs/prompts/_inbox.md
assert "docs/prompts/README.md exists"     test -f docs/prompts/README.md
assert "scripts/archive-prompts.sh exists" test -f scripts/archive-prompts.sh
assert "scripts/memory.sh exists"          test -f scripts/memory.sh
assert "scripts/statusline.sh exists"      test -f scripts/statusline.sh
assert "scripts/session-briefing.sh exists" test -f scripts/session-briefing.sh
assert "scripts/notify-blocked.sh exists"  test -f scripts/notify-blocked.sh
assert "scripts/lessons.sh exists"         test -f scripts/lessons.sh
assert "scripts/lessons.sh executable"     test -x scripts/lessons.sh

echo ""
echo "=== Substitution ==="
assert "no {{PROJECT_NAME}} literal in CLAUDE.md" "! grep -q '{{PROJECT_NAME}}' CLAUDE.md"
assert "no {{PROJECT_NAME}} literal in RESUME.md" "! grep -q '{{PROJECT_NAME}}' RESUME.md"

echo ""
echo "=== JSON validity ==="
assert "settings.json valid JSON" "python3 -c 'import json; json.load(open(\".claude/settings.json\"))'"

echo ""
echo "=== settings.json content ==="
assert "Notification hook present" "grep -q Notification .claude/settings.json"

echo ""
echo "=== Git ==="
assert "git repo initialized"      test -d .git
assert "initial commit present"    "git log --oneline | grep -q bootstrap"

echo ""
echo "=== Memory dir (~/.claude-work/projects/<slug>/memory/) ==="
assert "memory dir exists"             test -d "$MEM_DIR"
assert "MEMORY.md present"             test -f "$MEM_DIR/MEMORY.md"
assert "feedback_terse_zh.md present"  test -f "$MEM_DIR/feedback_terse_zh.md"
assert "feedback_workflow_split.md present" test -f "$MEM_DIR/feedback_workflow_split.md"
assert "feedback_model_split.md present"    test -f "$MEM_DIR/feedback_model_split.md"
assert "env_paths.md present"          test -f "$MEM_DIR/env_paths.md"

echo ""
echo "=== Statusline ==="
assert "statusline shows empty on fresh bootstrap" "bash scripts/statusline.sh | grep -q 'empty'"

echo ""
echo "=== Scripts runnable ==="
assert "archive-prompts.sh --dry-run runs" "bash scripts/archive-prompts.sh --dry-run"
assert "memory.sh list runs"               "bash scripts/memory.sh list"
assert "statusline.sh outputs non-empty"   "bash scripts/statusline.sh | grep -q ."
assert "lessons.sh count runs"             "bash scripts/lessons.sh count >/dev/null"
assert "lessons.sh help runs"              "bash scripts/lessons.sh help >/dev/null"

echo ""
echo "================================"
total=$((pass + fail))
if [ "$fail" = 0 ]; then
    echo "PASS: $pass/$total checks passed."
    exit 0
else
    echo "FAIL: $fail/$total checks failed." >&2
    exit 1
fi
