# docs/prompts/

Cross-session mailbox for the planning Opus session ↔ executor Sonnet session.

## Flow
1. Planning Opus writes prompt into `_inbox.md`
2. Executor Sonnet runs `/inbox` slash command, picks up the latest prompt
3. After execution, prompt is archived as `YYYY-MM-DD-<slug>.md` in this directory
4. `_inbox.md` is reset to empty for the next handoff

See `docs/WORKFLOW.md` for full plan/execute split details.
