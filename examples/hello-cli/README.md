# hello-cli — example project

> This snapshot was produced with Claude Code (Opus + Sonnet) — concrete artifact, not a generalized example. The workflow itself is model-agnostic; the choice of Claude here just reflects what was actually used to ship.

## What this is

A static snapshot of a real Tandem project after one phase shipped.
`hello-cli` is not a runnable independent repository — there is no nested `.git`.
It lives inside the `Tandem` repo so you can browse the files and read the
diff history directly in the parent repo context.

The snapshot captures three logical states:

1. **Post-bootstrap** — what `bash bootstrap.sh hello-cli` produces (committed in this
   directory's history as `feat: examples/hello-cli/ — bootstrapped skeleton`).
2. **Planner prompt written** — the Opus prompt archived at
   `docs/prompts/2026-04-28-add-hello-script.md`.
3. **Phase 1 shipped** — `hello.sh` + smoke test, RESUME.md updated.

---

## How to read it

Open the files in this order:

1. **`WALKTHROUGH.md`** — narrative of the full plan/execute cycle. Read this first.
2. **`CLAUDE.md`** — the bootstrapped project context Claude Code loads each session.
3. **`docs/prompts/2026-04-28-add-hello-script.md`** — the Opus planner prompt that
   "produced" `hello.sh`. This is what `_inbox.md` looked like before `/inbox` ran.
4. **`hello.sh` + `tests/test_hello.sh`** — the feature and its smoke test.
5. **`RESUME.md`** — the post-Phase-1 work log.

---

## Try it locally

From within a clone of `Tandem`, run from the `examples/hello-cli/` directory:

```bash
cd examples/hello-cli

bash hello.sh world
# → Hello, world!

bash hello.sh
# → Usage: bash hello.sh <name>  (exits 1)

bash tests/test_hello.sh
# → PASS: 2/2 tests
```

---

## What's missing vs a real project

- **No memory directory** — memory lives at
  `~/.claude-work/projects/<slug>/memory/` on the developer's machine, outside any
  repo. See `docs/MEMORY_SYSTEM.md` in the Tandem root for what those files
  contain and how they get auto-loaded.
- **No `.git`** — would conflict with the parent `Tandem` repo. The "commits"
  of the demo project are narrated in `WALKTHROUGH.md` as text, not real git history.
- **No GitHub remote** — a real project would have `git remote add origin <url>` and
  a `git push` after the phase gate passes.

---

## To make this real

Run `bash bootstrap.sh hello-cli` somewhere else on your disk:

```bash
cd ~/Desktop/repo          # or wherever you keep projects
bash ~/Tandem/bootstrap.sh hello-cli
cd hello-cli
```

You will get the same skeleton (CLAUDE.md, RESUME.md, `.gitignore`, `.claude/`,
`docs/prompts/`) plus a real `.git` history and memory directory, ready to push.

Then follow `docs/TUTORIAL.md` for the full 30-minute first-feature walkthrough.
