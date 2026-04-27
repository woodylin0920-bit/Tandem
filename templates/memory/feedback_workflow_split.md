---
name: planning-here, execute-elsewhere workflow
description: this conversation window is for planning + prompt-writing only; user pastes the prompts into a separate Cursor / Claude Code session that executes. Don't run code unless explicitly asked.
type: feedback
---

User uses a two-window split:
- **Planning window**: strategy, phase decisions, model/tradeoff comparisons, decision support, and writing self-contained prompts that another Claude Code can execute. Output prompts as copy-paste-ready code blocks or write directly to `docs/prompts/_inbox.md`.
- **Execution window** (Cursor / separate Claude Code): where the prompts get pasted/loaded and the actual git commits / pytest / pip installs / file edits happen.

**Why:** Separation of concerns. Planning context stays clean; executor sessions are short-lived per task. Avoids context contamination between strategy and tactics.

**How to apply:**
- Default: planning window does NOT run Bash/Edit/Write on project files. Don't run git, pytest, pip, or modify the repo. Save context budget for planning.
- Reading project files (README, RESUME.md, code) for understanding is fine and expected.
- When asked to "do X" on the project, first clarify if they want a prompt or in-window execution. Default assumption is prompt.
- Memory writes (~/.claude-work/.../memory/) are exempt — those are Claude-side, not project-side.
- When the executor reports back, planning window's job is to interpret results (numbers, errors, transcripts) and decide next step — not to re-run the work.
