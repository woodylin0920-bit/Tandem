#!/usr/bin/env bash
# shared-init.sh — initialize ~/.claude-work/shared/ and link it to the GitHub private remote.
# Idempotent: safe to re-run (skips steps that are already done).
# Usage: bash scripts/shared-init.sh
set -euo pipefail

# 1. Check gh auth and determine owner
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
    echo "ERROR: not authenticated with GitHub. Run: gh auth login" >&2
    exit 1
fi

OWNER="${TANDEM_SHARED_OWNER:-$(gh api user --jq .login 2>/dev/null || true)}"
if [ -z "$OWNER" ]; then
    echo "ERROR: cannot determine GitHub owner — set TANDEM_SHARED_OWNER or run 'gh auth login'" >&2
    exit 1
fi

REMOTE_REPO="https://github.com/$OWNER/claude-shared.git"
SHARED_DIR="$HOME/.claude-work/shared"

echo "[shared-init] owner: $OWNER"
echo "[shared-init] target: $SHARED_DIR"
echo "[shared-init] remote: $REMOTE_REPO"
echo ""

# 2. Create remote repo (idempotent: skip if already exists)
if gh repo view "$OWNER/claude-shared" >/dev/null 2>&1; then
    echo "[shared-init] remote repo already exists — skipping creation"
else
    echo "[shared-init] creating GitHub private repo..."
    gh repo create "$OWNER/claude-shared" \
        --private --clone=false \
        --description "Cross-project shared layer for Claude Code self-use harness (memory + lessons)"
    echo "[shared-init] created: https://github.com/$OWNER/claude-shared"
fi

# 3. Initialize local dir (idempotent)
mkdir -p "$SHARED_DIR/memory" "$SHARED_DIR/lessons"

if [ -d "$SHARED_DIR/.git" ]; then
    echo "[shared-init] local git repo already exists — skipping init"
else
    echo "[shared-init] initializing local git repo..."
    cd "$SHARED_DIR"
    git init
    git branch -M main

    cat > README.md <<EOF
# claude-shared

Cross-project shared layer for the [Tandem](https://github.com/$OWNER/Tandem) Claude Code self-use harness.

## What's here

- `memory/` — shared feedback + reference memories, auto-linked into each project via `scripts/memory.sh sync`
- `lessons/` — cross-project lessons promoted from inbox archives via `scripts/lessons.sh review`

## Setup

```bash
bash scripts/shared-init.sh   # idempotent — safe to re-run
```
EOF

    cat > .gitignore <<'GITEOF'
.DS_Store
*.swp
*.swo
*~
GITEOF

    touch memory/.gitkeep lessons/.gitkeep

    git add .
    git commit -m "init: claude-shared layer"
    git remote add origin "$REMOTE_REPO"
    git push -u origin main
    echo "[shared-init] initialized and pushed."
fi

# 4. Ensure remote is set correctly
cd "$SHARED_DIR"
current_remote=$(git remote get-url origin 2>/dev/null || echo "")
if [ -z "$current_remote" ]; then
    git remote add origin "$REMOTE_REPO"
    echo "[shared-init] added remote origin"
elif [ "$current_remote" != "$REMOTE_REPO" ]; then
    echo "WARN: remote origin is '$current_remote', expected '$REMOTE_REPO'"
    echo "      If intentional, ignore. Otherwise: git -C $SHARED_DIR remote set-url origin $REMOTE_REPO"
fi

echo ""
echo "[shared-init] Done."
echo "  local:  $SHARED_DIR"
echo "  remote: $REMOTE_REPO"
echo ""
echo "Next: run 'bash scripts/memory.sh sync' in a Tandem project to link shared memories."
