#!/usr/bin/env bash
# Smoke test for hello.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HELLO="$SCRIPT_DIR/hello.sh"

# Test 1: basic greeting
out=$(bash "$HELLO" "world")
if [ "$out" != "Hello, world!" ]; then
    echo "FAIL test 1: expected 'Hello, world!', got '$out'" >&2
    exit 1
fi

# Test 2: missing arg should error
if bash "$HELLO" 2>/dev/null; then
    echo "FAIL test 2: should have errored on missing arg" >&2
    exit 1
fi

echo "PASS: 2/2 tests"
