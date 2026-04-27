# {{PROJECT_NAME}}

This project uses [Tandem](https://github.com/woodylin0920-bit/Tandem) workflow conventions.

## Skill routing

When the user's request matches a slash command, invoke it via the Skill tool as your FIRST action:

- `/inbox` → read `docs/prompts/_inbox.md` and execute as your prompt

## Workflow

This repo uses **plan / execute session split**:

- **Planning session**: strategy, decisions, prompt authoring. Writes prompts to `docs/prompts/_inbox.md`. (My setup: Claude Code with Opus, /effort high. Any reasoning-strong model works — see docs/MODEL_GUIDE.md.)
- **Execution session (via `/inbox`)**: commits, tests, push. Reads `_inbox.md` and executes literally. (My setup: Claude Code with Sonnet, /effort medium. Any execution-strong model works.)

After execution, the prompt is archived to `docs/prompts/<descriptive-name>.md`.

## Memory

Persistent memory at `~/.claude-work/projects/-Users-{user}-{repo-path}/memory/`. Auto-loaded each session.

See [Tandem docs](https://github.com/woodylin0920-bit/Tandem/tree/main/docs) for full conventions.
