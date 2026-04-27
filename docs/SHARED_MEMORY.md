# Shared memory layer

Tandem's shared memory layer means **Claude gets smarter as you work across projects**. Preferences, workflow rules, and lessons-learned that apply to *you* (not a specific repo) live once at `~/.claude-work/_shared/memory/` and are symlinked into every project.

## Layout

```
~/.claude-work/
├── _shared/memory/                    # user-level (your preferences, rules)
│   ├── MEMORY.md                      # shared index
│   ├── feedback_terse_zh.md           # real file
│   ├── feedback_workflow_split.md     # real file
│   └── ...
└── projects/<slug>/memory/            # project-local (state, history, decisions specific to one repo)
    ├── MEMORY.md                      # combined index (auto-maintained)
    ├── feedback_terse_zh.md           # symlink → ../../../_shared/memory/feedback_terse_zh.md
    ├── feedback_workflow_split.md     # symlink
    ├── env_paths.md                   # real file (project-specific content)
    ├── project_current_handoff.md     # real file
    └── project_*.md                   # other project-only memories
```

## Load order

Claude Code's auto-memory loads `~/.claude-work/projects/<slug>/memory/MEMORY.md`, which contains:

1. **`<!-- BEGIN shared --> ... <!-- END shared -->`** — entries from `~/.claude-work/_shared/memory/MEMORY.md`, auto-injected by `scripts/memory.sh sync`. Do not edit between markers (will be overwritten on next sync).
2. **`<!-- BEGIN project-local --> ... <!-- END project-local -->`** — your project-specific entries. Edit freely. Untouched by sync.

When a same-named file exists in both shared and project, **project wins** — sync detects the conflict, leaves the project file alone, and prints:
```
Overridden by project (1):
  feedback_terse_zh.md   [project file kept; shared entry shadowed]
```

This lets you tweak a shared rule for one specific project without breaking it elsewhere.

## Workflow

### First-time setup

The first `bash bootstrap.sh <name>` run seeds `~/.claude-work/_shared/memory/` from `templates/memory/`. Subsequent bootstraps reuse the existing shared layer.

### Adding a new shared memory

1. Write the new memory file directly into `~/.claude-work/_shared/memory/foo.md`
2. Add an entry to `~/.claude-work/_shared/memory/MEMORY.md`
3. In each project where you want it active, run `bash scripts/memory.sh sync` — symlink + project MEMORY.md regen

### Adding a new project-local memory

Just create the file in `~/.claude-work/projects/<slug>/memory/foo.md` and add to the project-local section of `MEMORY.md`. No sync needed — sync only manages the shared section.

### Overriding a shared memory for one project

```bash
cd ~/path/to/some-project
rm "$HOME/.claude-work/projects/$(pwd | sed 's|/|-|g')/memory/feedback_terse_zh.md"   # remove symlink
echo "<override content>" > "$HOME/.claude-work/projects/$(pwd | sed 's|/|-|g')/memory/feedback_terse_zh.md"
bash scripts/memory.sh sync   # marks override + warns
```

### Migrating existing project memory to shared

Use the interactive `promote` helper:

```bash
bash scripts/memory.sh promote
```

It walks through every real file in your project memory dir and prompts per file:

```
[3/12] feedback_terse_zh.md
  name: terse Mandarin updates
  description: reply in 繁中, 1-2 sentences...
  type: feedback

Action? [p]romote / [k]eep / [d]elete / [s]kip / [q]uit:
```

- **`p` promote** — moves the file to `~/.claude-work/_shared/memory/`, adds an entry to shared `MEMORY.md`, and re-syncs the project (the file becomes a symlink in your project dir, available to *every* project that sync's).
- **`k` keep** — leaves the file as project-local.
- **`d` delete** — permanent delete (asks for `y` confirmation).
- **`s` skip** — decide later; the file stays untouched and appears again on next run.
- **`q` quit** — stops iteration; whatever's been promoted/kept/deleted so far is preserved.

If the shared layer already has a same-named file, `promote` asks: overwrite shared / rename local / cancel.

After running, your project MEMORY.md is updated automatically — promoted entries appear in the `<!-- BEGIN shared -->` section, deleted entries are removed.

## Safety

- `sync` never modifies real files in your project memory dir
- `sync` never deletes anything
- `sync` is idempotent — running twice is safe
- Conflicts (real local file with shared name) are reported, not auto-resolved
