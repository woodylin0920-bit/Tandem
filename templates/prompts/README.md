# docs/prompts/

Cross-session prompt mailbox + archive.

## Files

- `_inbox.md` — current prompt (gitignored, transient)
- `<descriptive-name>.md` — archived prompts (committed, self-handoff for future sessions)

## Inbox handoff flow

1. **Planning session** (terminal Opus) writes a self-contained prompt to `_inbox.md`
2. **Execution session** (Sonnet) types `/inbox`
3. Slash command reads `_inbox.md`, executes literally
4. After commits, archives `_inbox.md` content to `<descriptive-name>.md`, clears `_inbox.md`

## Why

- Eliminates copy-paste friction between two Claude sessions
- Archived prompts = self-documenting project history
- Each prompt is atomic + self-contained = future-you can re-read and understand intent
