# Troubleshooting

Known gotchas, in roughly the order you'll hit them. Each entry: symptom → cause → fix.

---

### `gh: command not found` / `gh auth status` fails

**Symptom**: Running `gh auth status` or any `gh` command prints `command not found` or `gh: No git credentials set for github.com`.

**Cause**: GitHub CLI is not installed, or installed but not authenticated.

**Fix**:
```bash
# macOS
brew install gh
gh auth login   # follow interactive prompts; choose HTTPS + browser

# Linux (Debian/Ubuntu)
sudo apt install gh
gh auth login
```

After login: `gh auth status` should show `Logged in to github.com`.

---

### `bootstrap.sh` leaves `{{PROJECT_NAME}}` literal in files

**Symptom**: `CLAUDE.md` or `RESUME.md` contains the literal string `{{PROJECT_NAME}}` instead of your project name.

**Cause**: You are running an older version of `bootstrap.sh` (before commit `e961c2e`). The early version did not have the `sed -i ''` substitution step.

**Fix**:
```bash
# Option A: pull the latest harness and re-bootstrap (if project is new)
cd ~/woody-harness && git pull

# Option B: fix in-place (BSD sed — macOS and BSD Linux)
find . -type f -exec sed -i '' 's/{{PROJECT_NAME}}/yourprojectname/g' {} +

# Option C: if on GNU Linux (sed -i without the empty string arg)
find . -type f -exec sed -i 's/{{PROJECT_NAME}}/yourprojectname/g' {} +
```

---

### macOS `sed -i` examples fail on Linux

**Symptom**: Copying a `sed -i ''` command from these docs fails on Linux with `sed: invalid option -- ' '` or unexpected behavior.

**Cause**: macOS ships BSD sed, which requires an explicit empty string argument (`-i ''`) after `-i`. GNU sed (Linux default) treats `-i` differently and does not accept the empty argument in the same position.

**Fix**: When adapting any `sed -i ''` command from this repo for GNU/Linux, remove the `''`:
```bash
# BSD (macOS):   sed -i '' 's/foo/bar/g' file.txt
# GNU (Linux):   sed -i 's/foo/bar/g' file.txt
```

All docs in this repo use the BSD form. Linux users adjust accordingly.

---

### Python venv inside iCloud Drive folder is extremely slow

**Symptom**: `import torch` or other heavy imports take 20+ minutes instead of seconds. `fileproviderd` shows high CPU in Activity Monitor.

**Cause**: iCloud Drive syncs every `.pyc` and `.so` file as the Python import system reads them. On a large venv, this intercepts thousands of file reads per second.

**Fix**: Move the venv outside iCloud-synced directories. The harness templates default to `~/venvs/<project>-venv/` which is outside `~/Desktop/` and `~/Documents/`.

```bash
# Move existing venv out
mv ~/Desktop/repo/myproject/venv ~/venvs/myproject-venv

# Update any scripts that reference the old path
# Symlink back if needed (optional)
ln -s ~/venvs/myproject-venv ~/Desktop/repo/myproject/venv
```

Never put venvs in `~/Desktop/`, `~/Documents/`, or any folder inside `~/Library/Mobile Documents/`.

---

### `/inbox` says "no prompt found" or reads an empty file

**Symptom**: You type `/inbox` in the Sonnet session and it reports that `_inbox.md` is empty or missing.

**Cause**: Current working directory mismatch. The Sonnet session's `cwd` is not the project root, so it looks for `docs/prompts/_inbox.md` in the wrong place.

**Fix**:
```bash
# In the Sonnet terminal, check:
pwd   # should be your project root (e.g. /Users/you/Desktop/repo/hello-world)

# If wrong, exit Claude Code and re-open from the right directory:
cd /path/to/your/project
claude --model sonnet
```

Both the planning session and executor session must have the same project root as their `cwd`.

---

### Executor ignores the planner's prompt / makes up its own plan

**Symptom**: Sonnet doesn't follow `_inbox.md` literally — it improvises, skips steps, or asks clarifying questions that were already answered in the prompt.

**Cause**: Wrong model. If you opened the executor session with plain `claude` (no `--model` flag), you are running Opus 4.7 which has a stronger tendency to plan and reason rather than execute literally.

**Fix**: Confirm the executor session is Sonnet:
```bash
claude --model sonnet
```

In the session, you can check with `/model` or `/config`. Opus plans; Sonnet executes. If you are intentionally using Opus for execution (e.g. a hard debugging task), write a more explicit prompt with `/effort high`.

---

### `git push` rejected: "tip of current branch is behind"

**Symptom**: `git push origin main` fails with `Updates were rejected because the tip of your current branch is behind its remote counterpart`.

**Cause**: The planner session (Opus) made commits in its own terminal, or you pushed from a different machine. The executor session's `HEAD` is now behind `origin/main`.

**Fix**:
```bash
git pull --ff-only origin main
# If fast-forward fails (diverged history), investigate before force-pushing
git log --oneline origin/main..HEAD
git log --oneline HEAD..origin/main
```

Fast-forward only (`--ff-only`) is safer than `git pull --rebase` when you are not sure what diverged. If it fails, look at both sides before deciding how to merge.

---

### Memory not auto-loading in new Claude Code session

**Symptom**: Claude Code starts a new session but doesn't seem to know about your workflow preferences (no mention of terse replies, model split, etc.).

**Cause**: The memory directory path does not match the expected slug format. Claude Code auto-loads `~/.claude-work/projects/<slug>/memory/MEMORY.md` where `<slug>` is the absolute project path with `/` replaced by `-`.

**Fix**: Derive the expected slug and verify the directory exists:
```bash
pwd
# e.g. /Users/you/Desktop/repo/hello-world

# Derive slug:
pwd | sed 's|/|-|g'
# e.g. -Users-you-Desktop-repo-hello-world

ls ~/.claude-work/projects/-Users-you-Desktop-repo-hello-world/memory/
# Should show MEMORY.md and the four template files
```

If the directory is missing, re-run bootstrap, or manually copy from `~/woody-harness/templates/memory/`.

---

### `/phase-gate` fails on a fresh bootstrapped project

**Symptom**: Immediately after `bootstrap.sh`, running `/phase-gate` in the executor session fails Gate 1 (no tests found / pytest exits nonzero).

**Cause**: Expected. A freshly bootstrapped project has no tests and no pytest configuration. The gate is designed to catch regressions — on a blank project, there is nothing to gate yet.

**Fix**: Either:
- Add at least one test file before running `/phase-gate` (recommended for non-trivial projects).
- For doc-only or setup-only commits, skip Gate 1 explicitly (see the Exceptions section in `docs/PHASE_GATING.md`).
- Bootstrap commit itself is explicitly exempted from all gates.

---

### `/codex-audit` says `codex: command not found`

**Symptom**: Running `/codex-audit` prints an error that the `codex` binary is not found.

**Cause**: The OpenAI Codex CLI is not installed. woody-harness does not bundle it — it is a separate dependency.

**Fix**: Install per the [OpenAI Codex CLI docs](https://github.com/openai/codex). As of 2026, the install is typically:
```bash
npm install -g @openai/codex
codex --version
```

Alternatively, use the `codex` gstack skill inside Claude Code if it is available in your setup.

---

### SessionStart briefing didn't print after bootstrap

**Symptom**: You open a new Claude Code session in a bootstrapped project and the `RESUME.md` preview / recent commits are not printed.

**Cause**: Either (a) `.claude/settings.json` was not copied by bootstrap, or (b) `RESUME.md` does not exist in the project root.

**Fix**:
```bash
# Check settings.json
cat .claude/settings.json   # should contain the SessionStart hook

# Check RESUME.md
ls RESUME.md   # should exist

# If settings.json is missing: re-bootstrap (for new projects) or copy manually
cp ~/woody-harness/.claude/settings.json .claude/settings.json

# If RESUME.md is missing: copy template
cp ~/woody-harness/templates/RESUME.md RESUME.md
```

If you bootstrapped before Phase 4b (before commit `feat: SessionStart auto-briefing hook + bootstrap copies all commands + settings.json` was in the harness), you may need to copy these files manually.

---

### `/resume` slash command not found

**Symptom**: Typing `/resume` in the executor session returns "command not found" or lists available commands without `/resume`.

**Cause**: The project was bootstrapped before Phase 4b, when `resume.md` was not yet in `.claude/commands/`.

**Fix**:
```bash
# Copy from the harness
cp ~/woody-harness/.claude/commands/resume.md .claude/commands/resume.md
git add .claude/commands/resume.md
git commit -m "chore: backfill /resume slash command from harness Phase 4b"
```

---

## Still stuck?

Open an issue using the bug template:
[github.com/woodylin0920-bit/woody-harness/issues/new/choose](https://github.com/woodylin0920-bit/woody-harness/issues/new/choose)

Include this in your report:

```bash
git log --oneline -5
bash --version
uname -a
```

The more context you give, the faster it gets triaged.
