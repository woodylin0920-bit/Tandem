---
name: terse Mandarin updates, no progress narration
description: user prefers very short Mandarin replies and dislikes mid-task "are you done yet" prompts; mid-task pings mean "give a short status," not "stop"
type: feedback
---

User communicates in 繁體中文 and prefers terse, no-fluff replies. Mid-task they may ping with things like 「好了嗎」 — that is a status check, not an instruction to stop. Continue working but acknowledge the question with a one-line update before resuming tool calls.

**Why:** Quick communication is the user's working style. Long progress recaps slow them down.

**How to apply:** Reply in 繁體中文 by default, keep updates to 1-2 sentences, never write multi-paragraph progress summaries unless the user explicitly asks. Resume the queued work in the same turn.
