# Phase 1 — add hello.sh greeting script

## Context
- Fresh bootstrapped project. No feature yet.
- Goal: ship a minimal greeting CLI that proves the harness loop works end-to-end.

## Working directory
All commands from project root (where this file's grandparent is).
```bash
pwd          # should end in /hello-cli
git status   # must be clean
```

## Deliverables — 2 atomic commits

### Commit 1 — `hello.sh` at project root
- Bash script taking one positional arg (`name`)
- Print `Hello, <name>!` and exit 0
- If no arg: print usage to stderr and exit 1
- Use `set -euo pipefail`
- Shebang: `#!/usr/bin/env bash`

**Subject**: `feat: add hello.sh greeting CLI`

### Commit 2 — `tests/test_hello.sh` smoke test
- Test 1: `bash hello.sh world` outputs exactly `Hello, world!`
- Test 2: `bash hello.sh` (no args) exits non-zero
- Print `PASS: 2/2 tests` on success
- Use `set -euo pipefail`

**Subject**: `test: smoke test for hello.sh`

## Hard constraints
- No external dependencies (POSIX-ish bash only).
- No comments inside hello.sh beyond the shebang + usage comment.
- After both commits, run `bash tests/test_hello.sh` to verify locally before reporting done.

## Reply format
```
✅ Phase 1 shipped — 2 commits

<git log --oneline -3>
<bash tests/test_hello.sh output>
```
