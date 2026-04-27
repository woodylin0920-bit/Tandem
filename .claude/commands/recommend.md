Read `docs/MODEL_GUIDE.md` first, then use its heuristic table to recommend a model + effort for the task the user described.

Output exactly this block (copy-paste ready for `## Execution profile`):

```
model: <opus|sonnet|haiku>
effort: <low|medium|high|xhigh>
why: <1-2 sentences citing which row in the MODEL_GUIDE table matches, and why>
```

Rules:
- Match the user's task description to the closest row(s) in the heuristic table.
- If two rows tie, pick the more conservative option (higher model tier or higher effort).
- If the task is ambiguous, ask one clarifying question before recommending.
- Do not explain the whole table. Output the block and one line of reasoning, nothing else.
