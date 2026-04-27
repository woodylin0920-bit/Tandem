#!/usr/bin/env bash
# auto-loop.sh — queue management for /auto mode
# Subcommands:
#   next                          → echo next queue file path; exit 1 if empty
#   archive <path>                → move task file to _archive/YYYY-MM/
#   notify <success|fail> <name>  → notify per TANDEM_AUTO_NOTIFY env (default: fail)
#   status                        → print queue state
#   recover                       → warn about stale .running/ files from interrupted sessions
#   lock                          → acquire executor mutex (delegates to executor-lock.sh)
#   unlock                        → release executor mutex
set -euo pipefail
cd "$(git rev-parse --show-toplevel)" || { echo "not in a git repo" >&2; exit 1; }

QUEUE_DIR="docs/prompts/_queue"
RUNNING_DIR="$QUEUE_DIR/.running"
ARCHIVE_ROOT="docs/prompts/_archive"

cmd="${1:-status}"

case "$cmd" in
  next)
    mkdir -p "$RUNNING_DIR"
    file=$(ls "$QUEUE_DIR"/*.md 2>/dev/null | sort | head -1 || true)
    if [ -z "$file" ]; then
      exit 1
    fi
    slug=$(basename "$file")
    # atomic claim: mv is same-filesystem so it's atomic on Linux/macOS
    mv "$file" "$RUNNING_DIR/$slug" 2>/dev/null || exit 1  # race lost → treat as empty
    echo "$RUNNING_DIR/$slug"
    ;;

  archive)
    path="${2:-}"
    [ -z "$path" ] && { echo "usage: auto-loop.sh archive <path>" >&2; exit 1; }
    [ -f "$path" ] || { echo "file not found: $path" >&2; exit 1; }
    target=$(realpath "$path")
    queue_dir=$(realpath "$QUEUE_DIR")
    case "$target" in
      "$queue_dir"/*) ;;
      *) echo "[auto-loop] archive refused: path outside _queue/: $path" >&2; exit 1 ;;
    esac
    base=$(basename "$path")
    # Extract YYYY-MM from YYYYMMDD prefix (queue files: YYYYMMDD-HHMMSS-slug.md)
    prefix=$(echo "$base" | grep -oE '^[0-9]{8}' || true)
    if [ -n "$prefix" ]; then
      yyyymm="${prefix:0:4}-${prefix:4:2}"
    else
      yyyymm=$(date +%Y-%m)
    fi
    target_dir="$ARCHIVE_ROOT/$yyyymm"
    mkdir -p "$target_dir"
    # Files from .running/ are gitignored (untracked), so git mv will fail; fall back to mv + add
    git mv "$path" "$target_dir/$base" 2>/dev/null || {
      mv "$path" "$target_dir/$base"
      git add "$target_dir/$base"
    }
    echo "archived: $base → _archive/$yyyymm/"
    ;;

  notify)
    result="${2:-success}"
    task_name="${3:-task}"
    mode="${TANDEM_AUTO_NOTIFY:-fail}"
    # none → always silent; fail → only notify on fail; all → always notify
    if [ "$mode" = "none" ]; then
      exit 0
    fi
    if [ "$mode" = "fail" ] && [ "$result" = "success" ]; then
      exit 0
    fi
    if [ "$result" = "fail" ]; then
      osascript -e "display notification \"⚠️ blocked — $task_name\" with title \"Tandem · auto failed\" sound name \"Funk\"" 2>/dev/null || true
      say -v Mei-Jia "卡住了" 2>/dev/null || true
    else
      osascript -e "display notification \"✅ done — $task_name\" with title \"Tandem · auto done\" sound name \"Glass\"" 2>/dev/null || true
    fi
    ;;

  status)
    mkdir -p "$QUEUE_DIR"
    files=$(ls "$QUEUE_DIR"/*.md 2>/dev/null | sort || true)
    if [ -z "$files" ]; then
      echo "auto: queue empty"
    else
      count=$(echo "$files" | wc -l | tr -d ' ')
      echo "auto: $count task(s) in queue"
      echo "$files" | while IFS= read -r f; do echo "  $(basename "$f")"; done
    fi
    ;;

  recover)
    mkdir -p "$RUNNING_DIR"
    stale=$(ls "$RUNNING_DIR"/*.md 2>/dev/null || true)
    if [ -z "$stale" ]; then
      echo "recover: .running/ is clean"
    else
      echo "[auto-loop] WARNING: stale files in .running/ (previous session interrupted):"
      echo "$stale" | while IFS= read -r f; do echo "  $(basename "$f")"; done
      echo "Move them back to _queue/ to retry, or archive manually."
    fi
    ;;

  lock)
    bash "$(dirname "$0")/executor-lock.sh" acquire
    ;;

  unlock)
    bash "$(dirname "$0")/executor-lock.sh" release
    ;;

  *)
    echo "usage: auto-loop.sh <next|archive|notify|status|recover>" >&2
    exit 1
    ;;
esac
