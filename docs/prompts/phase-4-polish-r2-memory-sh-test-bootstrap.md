# Phase 4-polish round 2 — S-2 memory portability + S-3 bootstrap test

## Context
- Repo: `/Users/woody/Desktop/repo/public/woody-harness/` (36 commits + v0.4.0 tag in main)
- Pre-approved 第 2 輪 polish sequence per `feedback_inbox_auto_queue` rule. 2 deliverables + auto-archive = 3 commits.
- After this ships, executor stops. Auto-queue authorization expires here. Planner waits for next user input.

## Working directory
**ALL commands from `/Users/woody/Desktop/repo/public/woody-harness/`.**

Pre-flight:
```bash
cd /Users/woody/Desktop/repo/public/woody-harness/
pwd
git status                  # must be clean
git pull --ff-only origin main
ls scripts/                 # baseline: archive-prompts.sh exists
```

## Commit convention (unchanged)
- Subject only, no co-author trailer.
- Types: `feat`, `fix`, `docs`, `chore`.

---

## Deliverables — 2 atomic commits + archive

### Commit 1 — S-2: `scripts/memory.sh` + bootstrap.sh copy + settings.json allowlist

**Purpose**: 換機 / 多裝置 / Claude Code 升版時，`~/.claude-work/projects/<slug>/memory/` 不會變孤兒。`memory.sh` 提供 export / import / list 子命令。

**File 1**: `scripts/memory.sh` (new) — full content:

```bash
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
```

**File 2 edit**: `bootstrap.sh` — find the existing `# Copy archive helper` block (added in Phase 4d). After the `cp ... archive-prompts.sh ...` line, ADD:
```bash
cp "$HARNESS_DIR/scripts/memory.sh" scripts/memory.sh
```
(One additional line. Same pattern. No chmod +x — invocation via `bash scripts/...`.)

**File 3 edit**: `.claude/settings.json` — add `"Bash(bash scripts/memory.sh:*)"` to the `permissions.allow` array. Final allow array order:
```json
"allow": [
  "Bash(osascript:*)",
  "Bash(say:*)",
  "Bash(bash scripts/archive-prompts.sh:*)",
  "Bash(bash scripts/memory.sh:*)"
]
```
Verify `python3 -c "import json; json.load(open('.claude/settings.json'))"` after edit.

**Verification BEFORE committing**:
```bash
# 1. memory.sh works on current repo
bash scripts/memory.sh list
# Expected: prints current memory dir path + ls of files

bash scripts/memory.sh export
# Expected: prints exported tarball path under ~/.claude-work/exports/

# 2. bootstrap.sh now copies it
cd /tmp && rm -rf wh-mem-test
bash /Users/woody/Desktop/repo/public/woody-harness/bootstrap.sh wh-mem-test
ls /tmp/wh-mem-test/scripts/
# Expected: archive-prompts.sh + memory.sh
bash /tmp/wh-mem-test/scripts/memory.sh list
# Expected: prints fresh memory dir path

# 3. cleanup test artifact
rm -rf /tmp/wh-mem-test
rm -rf "$HOME/.claude-work/projects/-tmp-wh-mem-test"
cd /Users/woody/Desktop/repo/public/woody-harness/
```
If any step diverges — FIX before committing.

**Commit subject**: `feat: scripts/memory.sh — export/import/list auto-memory dir`

---

### Commit 2 — S-3: `scripts/test-bootstrap.sh` (new)

**Purpose**: regression-proof bootstrap. Run this whenever templates change to verify a fresh bootstrap produces a working project.

**File**: `scripts/test-bootstrap.sh` (new) — full content:

```bash
#!/usr/bin/env bash
# Smoke test for bootstrap.sh — verify a fresh bootstrap produces a working project.
# Run from harness repo root: bash scripts/test-bootstrap.sh
# Exits 0 on pass, 1 on any failure. Cleans up test project + memory dir on exit.
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
echo "=== File presence (12 files) ==="
assert "CLAUDE.md exists"                  test -f CLAUDE.md
assert "RESUME.md exists"                  test -f RESUME.md
assert ".gitignore exists"                 test -f .gitignore
assert ".claude/settings.json exists"      test -f .claude/settings.json
assert ".claude/commands/inbox.md exists"  test -f .claude/commands/inbox.md
assert ".claude/commands/resume.md exists" test -f .claude/commands/resume.md
assert ".claude/commands/phase-gate.md exists"  test -f .claude/commands/phase-gate.md
assert ".claude/commands/codex-audit.md exists" test -f .claude/commands/codex-audit.md
assert "docs/prompts/_inbox.md exists"     test -f docs/prompts/_inbox.md
assert "docs/prompts/README.md exists"     test -f docs/prompts/README.md
assert "scripts/archive-prompts.sh exists" test -f scripts/archive-prompts.sh
assert "scripts/memory.sh exists"          test -f scripts/memory.sh

echo ""
echo "=== Substitution ==="
assert "no {{PROJECT_NAME}} literal in CLAUDE.md" "! grep -q '{{PROJECT_NAME}}' CLAUDE.md"
assert "no {{PROJECT_NAME}} literal in RESUME.md" "! grep -q '{{PROJECT_NAME}}' RESUME.md"

echo ""
echo "=== JSON validity ==="
assert "settings.json valid JSON" "python3 -c 'import json; json.load(open(\".claude/settings.json\"))'"

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
echo "=== Scripts runnable ==="
assert "archive-prompts.sh --dry-run runs" "bash scripts/archive-prompts.sh --dry-run"
assert "memory.sh list runs"               "bash scripts/memory.sh list"

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
```

**Verification BEFORE committing** — run the test against the harness itself:
```bash
bash scripts/test-bootstrap.sh
```
Expected: all checks ✅, exit 0, last line `PASS: N/N checks passed.` If anything ❌ — FIX (likely a missing copy in bootstrap.sh) before committing. Do NOT commit a failing test.

**Commit subject**: `feat: scripts/test-bootstrap.sh — regression smoke for bootstrap`

---

## Hard constraints
1. **NO co-author / Claude trailers** in commits.
2. **DO NOT** modify files outside: `scripts/memory.sh` (commit 1, new), `bootstrap.sh` (commit 1), `.claude/settings.json` (commit 1), `scripts/test-bootstrap.sh` (commit 2, new).
3. **DO NOT** start any next task — auto-queue authorization expires after this 2-commit round. Even if S-1 / T-1 seem natural to chain, STOP.
4. If commit 1's bootstrap dry-run fails, STOP and report — do not commit broken bootstrap.
5. If commit 2's `bash scripts/test-bootstrap.sh` fails any check, STOP and report. The test must pass before being committed.
6. Settings.json must remain valid JSON after every edit — verify with `python3 -c "import json; json.load(open('.claude/settings.json'))"`.
7. Cleanup any `/tmp/wh-mem-test*` / `/tmp/wh-bootstrap-test-*` test dirs after verification, including their corresponding `~/.claude-work/projects/-tmp-...` memory dirs.

## Reply format when done
Per current `/inbox` convention: archive prompt + append `## Result` block + fire macOS notification + reply 1-2 sentences in 繁中. Result block include:

```
**Status**: ✅ shipped
**Commits**: 2 (+ archive auto-commit)
<git log --oneline of the 2 deliverable commits>

**Verification**:
- memory.sh export from harness: <archive path + size>
- bootstrap.sh copies memory.sh: yes
- test-bootstrap.sh: PASS N/N checks
- settings.json valid: yes

**Push**: ✅ pushed to origin/main
**Blockers**: <none | description>
```

Then stop. Do NOT auto-queue T-1 / S-1 / 4e — auto-queue authorization is sequence-bounded.

## Result

**Status**: ✅ shipped
**Commits**: 2 (+ archive auto-commit)
7ebfc44 feat: scripts/memory.sh — export/import/list auto-memory dir
981796f feat: scripts/test-bootstrap.sh — regression smoke for bootstrap

**Verification**:
- memory.sh export from harness: /Users/woody/.claude-work/exports/...-memory-20260427-0649.tar.gz (20K, 15 files)
- bootstrap.sh copies memory.sh: yes (ls /tmp/wh-mem-test/scripts/ shows both archive-prompts.sh + memory.sh)
- test-bootstrap.sh: PASS 25/25 checks
- settings.json valid: yes

**Push**: ✅ pushed to origin/main
**Blockers**: none
