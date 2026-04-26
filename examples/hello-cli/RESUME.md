# hello-cli — RESUME

## Status
Phase 1 shipped: `hello.sh` + smoke test (2 commits, 2026-04-28).

## What works
- `bash hello.sh <name>` prints `Hello, <name>!`
- `bash tests/test_hello.sh` returns `PASS: 2/2 tests`

## Recent commits
- feat: add hello.sh greeting CLI
- test: smoke test for hello.sh

## Next
- Phase 2 candidate: support multiple names (`hello.sh alice bob` → multi-line greeting)
- Or: package as installable command
- Open `docs/prompts/_inbox.md` and write a planner prompt to begin.
