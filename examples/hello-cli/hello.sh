#!/usr/bin/env bash
# hello.sh — print a greeting. Usage: bash hello.sh <name>
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: bash hello.sh <name>" >&2
    exit 1
fi

echo "Hello, $1!"
