#!/usr/bin/env bash
# executor-lock.sh — session-scoped mutex for /auto and /inbox
# Prevents two executor sessions from running simultaneously.
# Uses mkdir-based locking (atomic on macOS/Linux, no flock required).
#
# Subcommands:
#   acquire       → create lock; exit 1 if already held by another session
#   release       → remove lock
#   status        → print lock state
set -euo pipefail
cd "$(git rev-parse --show-toplevel)" || { echo "not in a git repo" >&2; exit 1; }

LOCK_DIR=".git/tandem-executor.lock.d"

_stale_check() {
  if [ -d "$LOCK_DIR" ]; then
    pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
      echo "[executor-lock] stale lock from dead pid $pid — removing" >&2
      rm -rf "$LOCK_DIR"
      return 1  # was stale, now removed
    fi
  fi
  return 0
}

cmd="${1:-status}"

case "$cmd" in
  acquire)
    _stale_check || true  # clean stale before trying
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      echo "$$" > "$LOCK_DIR/pid"
      echo "[executor-lock] acquired (pid $$)"
    else
      lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "unknown")
      echo "[executor] another session is running (pid $lock_pid) — abort" >&2
      exit 1
    fi
    ;;

  release)
    if [ -d "$LOCK_DIR" ]; then
      rm -rf "$LOCK_DIR"
      echo "[executor-lock] released"
    else
      echo "[executor-lock] no lock held"
    fi
    ;;

  status)
    if [ -d "$LOCK_DIR" ]; then
      pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "unknown")
      echo "[executor-lock] held by pid $pid"
    else
      echo "[executor-lock] free"
    fi
    ;;

  *)
    echo "usage: executor-lock.sh <acquire|release|status>" >&2
    exit 1
    ;;
esac
