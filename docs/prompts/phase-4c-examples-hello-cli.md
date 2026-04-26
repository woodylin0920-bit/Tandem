# Phase 4c — examples/hello-cli/ minimal demo project

## Context
- Repo: `/Users/woody/Desktop/repo/public/woody-harness/`
- Phase 1+2+4a+4b shipped (20 commits public). 4b just delivered TUTORIAL.md, HARNESS_ETHOS.md, TROUBLESHOOTING.md, CONTRIBUTING.md, MEMORY_SYSTEM.md, /resume command, SessionStart hook.
- Phase 4c = a **static snapshot directory** under `examples/hello-cli/` showing what a real bootstrapped project looks like + a worked plan/execute cycle that shipped one tiny feature (`hello.sh`).
- This is NOT a separate git repo — it's a directory inside woody-harness for browsers to open and read. No nested `.git`. The "commits" of the demo project are narrated in `WALKTHROUGH.md` as text, not as actual git history of a sub-repo.

## Working directory
**ALL commands from `/Users/woody/Desktop/repo/public/woody-harness/`.**

Pre-flight:
```bash
cd /Users/woody/Desktop/repo/public/woody-harness/
pwd                         # confirm woody-harness
git status                  # must be clean
git pull --ff-only origin main
ls examples/ 2>/dev/null    # baseline: examples/ should NOT exist yet
```
If working tree dirty or pull conflicts — STOP and report.

## Commit convention (unchanged)
- Subject only, no co-author trailer.
- Types: `feat`, `fix`, `docs`, `chore`.

## Reference material to read BEFORE writing
1. `bootstrap.sh` — to know exactly what files a fresh bootstrap produces (file list + PROJECT_NAME substitution behavior)
2. `templates/CLAUDE.md`, `templates/RESUME.md`, `templates/.gitignore`, `templates/prompts/_inbox.md`, `templates/prompts/README.md` — bootstrapped content sources
3. `.claude/commands/inbox.md`, `resume.md`, `phase-gate.md`, `codex-audit.md` — slash commands bootstrapped projects receive
4. `.claude/settings.json` — SessionStart hook bootstrapped projects receive
5. `docs/TUTORIAL.md` (just written in 4b) — to align example with the tutorial's wording
6. `docs/MEMORY_SYSTEM.md` (just written in 4b) — to know what to say about memory in the example's README
7. `docs/PHASE_GATING.md` — to align the example's "Phase 1 shipped" claim with the gate definition

The example must be **internally consistent with these existing files** — if you find a mismatch, NOTE in final report, don't silently fix.

---

## Final directory layout (after all 5 commits)

```
examples/hello-cli/
├── README.md                           # meta intro (this is a snapshot of...)
├── WALKTHROUGH.md                      # narrative: how this project got built
├── CLAUDE.md                           # bootstrapped, PROJECT_NAME=hello-cli
├── RESUME.md                           # filled to reflect "Phase 1 shipped: hello.sh"
├── .gitignore                          # bootstrapped (literal copy)
├── .claude/
│   ├── settings.json                   # bootstrapped (SessionStart hook)
│   └── commands/
│       ├── inbox.md                    # bootstrapped (literal copy)
│       ├── resume.md                   # bootstrapped (literal copy)
│       ├── phase-gate.md               # bootstrapped (literal copy)
│       └── codex-audit.md              # bootstrapped (literal copy)
├── docs/
│   └── prompts/
│       ├── README.md                   # bootstrapped (literal copy)
│       ├── _inbox.md                   # empty (post-execution state)
│       └── 2026-04-28-add-hello-script.md   # archived planner prompt
├── hello.sh                            # the actual feature
└── tests/
    └── test_hello.sh                   # smoke test
```

---

## Deliverables — 6 atomic commits, in order

### Commit 0 — purge `omni-sense` references (make framework generic)
**Purpose**: Strip the framework's narrative dependency on a single source project. Keep the *lessons*, drop the *attribution*. Reader should see a generic professional framework, not "X person's adapted notes".

**9 files to edit. Use the Edit tool with these EXACT replacements** (verify each old_string exists by reading the file first):

#### 1. `README.md`
- Line 7 — REPLACE
  - old: `Extracted from real-world omni-sense development (2026-04-21 → 2026-04-27): 4 ship-able phases + safety audit in 1 week.`
  - new: `Extracted from real-world solo project development: 4 ship-able phases + safety audit in 1 week.`
- Line 21 — REPLACE
  - old: `- **vs. writing your own**: extracted from a real shipped project (omni-sense), not a theoretical framework`
  - new: `- **vs. writing your own**: extracted from real shipped projects, not a theoretical framework`
- DELETE the entire `## Lineage` section (heading + body line `Born from [omni-sense]...`). Leave a single blank line where it was so the file ends cleanly. Section is around lines 46-49.

#### 2. `CHANGELOG.md`
- Line 15 — REPLACE
  - old: `- \`docs/CODEX_AUDIT.md\` — rationale + real case (omni-sense 6 P0s fixed)`
  - new: `- \`docs/CODEX_AUDIT.md\` — rationale + real case (6 P0s caught by audit)`

#### 3. `docs/WORKFLOW.md`
- Line 3 — REPLACE
  - old: `This is the day-to-day flow extracted from omni-sense (1 week, 4 phases, 6 P0 safety fixes).`
  - new: `This is the day-to-day flow battle-tested on solo project work (1 week, 4 phases, 6 P0 safety fixes resolved).`

#### 4. `docs/FUTURE.md`
- Line 9 — REPLACE
  - old: `**Captured**: 2026-04-27 (during omni-sense + harness Phase 1 dev)`
  - new: `**Captured**: 2026-04-27 (during harness Phase 1 dev)`
- Line 19 — REPLACE (inside ASCII art)
  - old: `│  inbox-omni-sense.md                        │`
  - new: `│  inbox-project-a.md                         │`
- Line 30 — REPLACE (inside ASCII art)
  - old: `│  ▼ omni-sense [working] commit 3/5 ...      │`
  - new: `│  ▼ project-a   [working] commit 3/5 ...     │`
- After replacing, EYEBALL the ASCII art alignment — the box's right border `│` must still line up. Adjust trailing spaces if needed so the right edge is consistent.

#### 5. `docs/HARNESS_ETHOS.md`
- Line 36 — REPLACE
  - old: `The gate exists because "I'll fix it later" doesn't happen. omni-sense learned this the hard way: six P0s discovered by codex audit after "shipping" Phase 1 — OCR prompt injection, silent hardware failures, a recursive crash in log_event, no watchdog, a bad TTS error path, a temp file leak. None of those would have shipped if a gate had existed earlier.`
  - new: `The gate exists because "I'll fix it later" doesn't happen. A recent solo project learned this the hard way: six P0s discovered by codex audit after "shipping" Phase 1 — prompt injection, silent device failures, a recursive crash in event logging, no watchdog, a bad error path, a temp file leak. None of those would have shipped if a gate had existed earlier.`
- Line 68 — REPLACE
  - old: `Ship-ready before scope-creep. When omni-sense Phase 2 (OCR) was ready to start, the codex audit surfaced six P0s from Phase 1 that had slipped through. All six were fixed before a single line of Phase 2 code was written.`
  - new: `Ship-ready before scope-creep. When a recent solo project's Phase 2 was ready to start, the codex audit surfaced six P0s from Phase 1 that had slipped through. All six were fixed before a single line of Phase 2 code was written.`
- Line 80 — REPLACE
  - old: `pytest green means the logic is correct under the test harness's assumptions. It does not mean the hardware works, the OS behaves, or the external dependency responds the way the mock said it would. For omni-sense — a blind-navigation pipeline — silent failure is a safety issue, not a test metric. A failing \`say\` command with no error feedback is a P0 regardless of what pytest says.`
  - new: `pytest green means the logic is correct under the test harness's assumptions. It does not mean the hardware works, the OS behaves, or the external dependency responds the way the mock said it would. For accessibility-critical or safety-critical projects, silent failure is a safety issue, not a test metric. A failing audio cue with no error feedback is a P0 regardless of what pytest says.`

#### 6. `docs/CODEX_AUDIT.md`
- Heading at line 32 — REPLACE
  - old: `## 真實案例：omni-sense 2026-04-27`
  - new: `## 真實案例：solo project audit (2026-04-27)`
- The body bullets ARE generic enough to leave as-is. No further edits in this file.

#### 7. `docs/SMOKE_TESTING.md`
- Heading at line 30 — REPLACE
  - old: `## 實際案例：omni-sense 2026-04-27`
  - new: `## 實際案例：solo project audit (2026-04-27)`
- Find the line containing `Test 3 是最關鍵 — 沒驗證之前不敢給視障者用。` and REPLACE
  - new: `Test 3 是最關鍵 — 沒驗證之前不敢交付給安全性需求高的使用者。`

#### 8. `templates/memory/env_paths.md`
- Line 13 — REPLACE
  - old: `**macOS iCloud trap (carried from omni-sense lesson):** Never put venv in`
  - new: `**macOS iCloud trap:** Never put venv in`
- (Only the prefix changes. Rest of the line stays.)

#### 9. `templates/prompts/CODEX_AUDIT.md`
- Line 89 — REPLACE
  - old: `| PROJECT_NAME | omni-sense |`
  - new: `| PROJECT_NAME | hello-cli |`
- Line 90 — REPLACE
  - old: `| PROJECT_DESCRIPTION_1_SENTENCE | 盲人導航 pipeline，本地全離線 |`
  - new: `| PROJECT_DESCRIPTION_1_SENTENCE | 範例 CLI 工具（greeting） |`
- Line 94 — REPLACE
  - old: `| TRIGGER_FLOW | 攝影機 → YOLO/OCR/Depth → 三層 LLM 警示 |`
  - new: `| TRIGGER_FLOW | CLI args → bash script → stdout greeting |`
- Line 95 — REPLACE
  - old: `| FILE_LIST | pipeline.py, chat.py, omni_sense_ocr.py, omni_sense_asr.py |`
  - new: `| FILE_LIST | hello.sh, tests/test_hello.sh |`
- Line 96 — REPLACE
  - old: `| TARGET_USER_DESCRIPTION | 視障使用者（沒有視覺 feedback 通道） |`
  - new: `| TARGET_USER_DESCRIPTION | CLI 使用者 |`

#### Verification BEFORE committing commit 0
```bash
# 1. No omni-sense references survive in shipped files
grep -rni "omni-sense\|omni_sense\|omnisense" --include="*.md" --include="*.sh" --include="*.json" --include="*.yml" . | grep -v "^./docs/prompts/" || echo "CLEAN: no omni-sense references in shipped files"
# 2. Archived prompt files MAY still contain references — that's a separate question. Report grep result for /docs/prompts/ separately:
grep -ni "omni" docs/prompts/*.md | grep -v "_inbox.md" || echo "Archives clean"
# 3. ASCII art in FUTURE.md still aligned
sed -n '15,35p' docs/FUTURE.md
```
If commit 0 verification finds remaining references in shipped (non-archive) files, FIX before committing. **Archived prompts under `docs/prompts/phase-*.md` ARE in scope — also scrub them**: do `sed -i '' 's/omni-sense/solo project/g; s/omni_sense/solo_project/g' docs/prompts/phase-*.md` and verify with grep again. If after scrubbing, semantic meaning of an archive line breaks (e.g., a sentence becomes nonsense), DO NOT manually rewrite — leave the archive as-is and note in final report.

**Commit subject**: `chore: remove omni-sense references — keep harness framework-generic`

---

### Commit 1 — bootstrapped skeleton (no feature yet)
**Purpose**: Snapshot of "what bootstrap.sh produces, BEFORE any feature work". Reader sees a fresh project state.

**Steps**:
1. `mkdir -p examples/hello-cli/.claude/commands examples/hello-cli/docs/prompts examples/hello-cli/tests`
2. Copy bootstrapped files (literal `cp` — no edits except `{{PROJECT_NAME}}` substitution where bootstrap.sh substitutes):
   - `cp templates/CLAUDE.md examples/hello-cli/CLAUDE.md` then `sed -i '' 's/{{PROJECT_NAME}}/hello-cli/g' examples/hello-cli/CLAUDE.md`
   - `cp templates/RESUME.md examples/hello-cli/RESUME.md` then `sed -i '' 's/{{PROJECT_NAME}}/hello-cli/g' examples/hello-cli/RESUME.md` — **but** for this commit RESUME.md should reflect a freshly-bootstrapped state (no Phase 1 yet). If templates/RESUME.md has placeholder content, leave it. Commit 3 will update RESUME.md to "Phase 1 shipped".
   - `cp templates/.gitignore examples/hello-cli/.gitignore`
   - `cp templates/prompts/_inbox.md examples/hello-cli/docs/prompts/_inbox.md`
   - `cp templates/prompts/README.md examples/hello-cli/docs/prompts/README.md`
   - `cp .claude/settings.json examples/hello-cli/.claude/settings.json`
   - `cp .claude/commands/inbox.md examples/hello-cli/.claude/commands/inbox.md`
   - `cp .claude/commands/resume.md examples/hello-cli/.claude/commands/resume.md`
   - `cp .claude/commands/phase-gate.md examples/hello-cli/.claude/commands/phase-gate.md`
   - `cp .claude/commands/codex-audit.md examples/hello-cli/.claude/commands/codex-audit.md`
3. `git add examples/hello-cli/` and verify with `git status` — ensure all expected files staged.
4. **DO NOT** add hello.sh, test_hello.sh, README.md, WALKTHROUGH.md, or 2026-04-28-add-hello-script.md yet — those come in later commits.
5. Verify _inbox.md is EXACTLY a single newline (post-execution empty state) — if templates/prompts/_inbox.md is non-empty, that's a separate problem; report and continue.

**Commit subject**: `feat: examples/hello-cli/ — bootstrapped skeleton (pre-feature snapshot)`

---

### Commit 2 — archive the planner prompt that "would have shipped" hello.sh
**Purpose**: Show the reader what a real planner prompt looks like — the same format Opus writes to `_inbox.md`.

**File**: `examples/hello-cli/docs/prompts/2026-04-28-add-hello-script.md`

**Content** (write this file VERBATIM — this is illustrative, not actually executed):

```markdown
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
```

**Commit subject**: `feat: examples/hello-cli/ — archive planner prompt that produced hello.sh`

---

### Commit 3 — ship the feature (`hello.sh` + test) + update RESUME.md
**Purpose**: Show what the executor produced. This is the "after /inbox runs" state.

**File 1**: `examples/hello-cli/hello.sh`
```bash
#!/usr/bin/env bash
# hello.sh — print a greeting. Usage: bash hello.sh <name>
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: bash hello.sh <name>" >&2
    exit 1
fi

echo "Hello, $1!"
```

**File 2**: `examples/hello-cli/tests/test_hello.sh`
```bash
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
```

**File 3**: `examples/hello-cli/RESUME.md` — REWRITE to reflect "Phase 1 shipped" state. Required content (replace whatever was bootstrapped in commit 1):

```markdown
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
```

**Verification BEFORE committing**:
```bash
bash examples/hello-cli/tests/test_hello.sh
# Expected: "PASS: 2/2 tests"
```
If test fails — FIX hello.sh or the test, do NOT commit broken code.

**Commit subject**: `feat: examples/hello-cli/ — ship hello.sh + smoke test (Phase 1 demo)`

---

### Commit 4 — `WALKTHROUGH.md` + `README.md`
**Purpose**: Tell the reader how to read this directory.

**File 1**: `examples/hello-cli/README.md`

Required H2 sections:
1. `## What this is` — A static snapshot of a real woody-harness project AFTER one phase shipped. Not a runnable independent repo (no nested `.git`); read the files + diff history in the parent woody-harness repo.
2. `## How to read it` — Open in this order: WALKTHROUGH.md → CLAUDE.md → docs/prompts/2026-04-28-add-hello-script.md → hello.sh + tests/test_hello.sh → RESUME.md.
3. `## Try it locally` — `bash hello.sh world` and `bash tests/test_hello.sh` (run from `examples/hello-cli/` cwd in the woody-harness clone).
4. `## What's missing vs a real project` — No memory dir (memory lives at `~/.claude-work/projects/<slug>/memory/`, outside any repo — see `docs/MEMORY_SYSTEM.md`). No `.git` (would conflict with the parent repo). No GitHub remote.
5. `## To make this real` — Run `bash bootstrap.sh hello-cli` somewhere ELSE on your disk; you'll get the same skeleton plus a real `.git` and memory dir, ready to push.

**Length**: 60-120 lines.

**File 2**: `examples/hello-cli/WALKTHROUGH.md`

Required H2 sections (narrative form):
1. `## The setup` — User ran `bash ~/woody-harness/bootstrap.sh hello-cli`. List actual files produced (read bootstrap.sh to be accurate). Snapshot at this state = commit 1 of this directory.
2. `## The plan (planner Opus session)` — User: "add a hello CLI". Planner read context, wrote a 25-line prompt to `docs/prompts/_inbox.md`. That prompt is preserved at `docs/prompts/2026-04-28-add-hello-script.md` (commit 2 of this directory).
3. `## The execution (executor Sonnet session)` — User typed `/inbox`. Sonnet read the prompt, wrote `hello.sh`, wrote `tests/test_hello.sh`, ran the test, made 2 atomic commits. State after = commit 3 of this directory.
4. `## The diff` — Show the conceptual `git log --oneline` of the demo project (3 lines: bootstrap commit, hello.sh commit, test commit) and a paste of `hello.sh` so the reader sees the artifact.
5. `## What you just saw` — 3-bullet recap: Plan/execute split / atomic commits / smoke test as gate.
6. `## Doing this yourself` — Pointer to `docs/TUTORIAL.md` for the full walkthrough on a real project.

**Length**: 100-180 lines.

**Commit subject**: `docs: examples/hello-cli/ — WALKTHROUGH + README narrating the loop`

---

### Commit 5 — cross-link from main docs
**Purpose**: Make the example discoverable from the entry points new users hit first.

**File 1**: `README.md` (woody-harness root) — INSERT a new section between "Quick start" and "Roadmap":

```markdown
## See it in action

[`examples/hello-cli/`](examples/hello-cli/) is a static snapshot of a real
bootstrapped project after one phase shipped. Browse the files + read
`WALKTHROUGH.md` to see the plan/execute cycle on a concrete artifact.
```

**File 2**: `docs/TUTORIAL.md` — at the end of `## Step 9 — Push + iterate` (or in the `## Next` section, whichever fits — read the file first), add ONE bullet:

```markdown
- See [`examples/hello-cli/`](../examples/hello-cli/) for a worked snapshot of a project that just shipped Phase 1 — read `WALKTHROUGH.md` for the narrative.
```

**File 3**: `CHANGELOG.md` — add an `## [Unreleased]` section at the top (under the `# Changelog` heading and Keep-a-Changelog reference line, BEFORE `## [0.2.0]`). Under it:
```markdown
### Added
- `examples/hello-cli/` — static snapshot demo with WALKTHROUGH narrating the plan/execute loop on a one-feature project (Phase 4c).
- `docs/TUTORIAL.md`, `docs/HARNESS_ETHOS.md`, `docs/TROUBLESHOOTING.md`, `docs/MEMORY_SYSTEM.md`, `CONTRIBUTING.md` (Phase 4b).
- `.claude/commands/resume.md` slash command + `.claude/settings.json` SessionStart hook + bootstrap copies all commands (Phase 4b).
- `LICENSE` (MIT), `CHANGELOG.md`, `.github/ISSUE_TEMPLATE/{bug,feature}.md` + `config.yml`, README rewrite, `docs/prompts/` self-hosting (Phase 4a).

### Changed
- Generalized origin-project attributions across docs and templates — lessons preserved, framework now stands on its own without referencing a single source project (Phase 4c).
```

If `## [Unreleased]` already exists for some reason, merge into it, don't duplicate. If unsure of CHANGELOG.md format, read it first.

**Commit subject**: `docs: cross-link examples/hello-cli/ from README + TUTORIAL + CHANGELOG`

---

## After all 6 commits
```bash
git log --oneline -10
bash examples/hello-cli/tests/test_hello.sh   # final sanity
git push origin main
git status
```

## Hard constraints
1. **NO co-author / Claude trailers** in commits.
2. **DO NOT** create a nested `.git` inside `examples/hello-cli/` — it's a static directory in the parent repo.
3. **DO NOT** modify existing files outside of: (a) the 9 files listed in commit 0's purge; (b) README.md / docs/TUTORIAL.md / CHANGELOG.md cross-links in commit 5. All other 4b-shipped docs stay untouched.
4. **DO NOT** start Phase 4d (model+effort recommendation) — separate prompt.
5. **DO NOT** chmod +x scripts — invocation via `bash <file>` works on all platforms; chmod adds VCS noise.
6. If `bash examples/hello-cli/tests/test_hello.sh` fails at any point, STOP and report — do not commit broken code.
7. If you find that templates/RESUME.md is empty or missing — STOP and report; don't fabricate baseline content.
8. RESUME.md update in commit 3 should REPLACE the bootstrapped baseline; commit 1's RESUME.md was the bootstrapped placeholder, commit 3's RESUME.md is the post-Phase-1 state. The diff should show the change clearly.

## Reply format when done
```
✅ Phase 4c shipped — 6 commits + push (1 omni-sense purge + 5 example)

<git log --oneline -10>

<bash examples/hello-cli/tests/test_hello.sh output>

<git status>

Contradictions found: <list or "none">

Ready for Phase 4d (model + /effort recommendation system).
```

Then stop. Do NOT proactively start 4d.
