# hello-cli

This project uses [woody-harness](https://github.com/woodylin0920-bit/woody-harness) workflow conventions.

## Skill routing

When the user's request matches a slash command, invoke it via the Skill tool as your FIRST action:

- `/inbox` → read `docs/prompts/_inbox.md` and execute as your prompt

## Workflow

This repo uses **plan / execute session split**:

- **Planning session (terminal Opus 4.7)**: strategy, decisions, prompt authoring. Writes prompts to `docs/prompts/_inbox.md`.
- **Execution session (Sonnet via `/inbox`)**: commits, pytest, push. Reads `_inbox.md` and executes literally.

After execution, the prompt is archived to `docs/prompts/<descriptive-name>.md`.

## Memory

Persistent memory at `~/.claude-work/projects/-Users-{user}-{repo-path}/memory/`. Auto-loaded each session.

See [woody-harness docs](https://github.com/woodylin0920-bit/woody-harness/tree/main/docs) for full conventions.
