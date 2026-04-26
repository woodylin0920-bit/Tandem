#!/usr/bin/env bash
# woody-harness bootstrap — create new project from harness templates.
# Usage: bash bootstrap.sh <project-name>
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: bash bootstrap.sh <project-name>"
    exit 1
fi

PROJECT_NAME="$1"
HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
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
