# Model Guide — picking model + effort for inbox rounds

How I pick which model + `/effort` setting goes into `## Execution profile` for each inbox round. Empirical, not theoretical — these patterns came from running 20+ inbox rounds in Tandem and earlier solo projects.

## TL;DR — default split

- **Planner session**: Claude Code with Opus, `/effort high` (bump to `xhigh` for architecture)
- **Executor session**: Claude Code with Sonnet, `/effort medium` (drop to `low` for trivial work)

This is what I run. Deviate when the task type matches one of the rows below.

## Heuristic table

| Task type | Model | Effort | Why |
|---|---|---|---|
| Strategy / phase design / tradeoff calls | Opus | high (xhigh for architecture) | Bad decisions propagate through future commits |
| Authoring inbox prompts | Opus | high | Prompt clarity == executor output quality |
| Mechanical rename / sed across repo | Sonnet | low | No reasoning, pure substitution; literalness is the asset |
| Single-file fix, < 50 lines, clear scope | Sonnet | low | Bounded edits — Sonnet's literalness shines |
| Multi-file refactor, design-light | Sonnet | medium | Several files but each well-defined |
| Multi-file refactor, design-heavy WITH explicit anchors | Sonnet | medium | Complex, but planner pre-decided structure → executor doesn't redesign |
| New feature: script + docs + tests | Sonnet | medium | Three surfaces, each well-bounded |
| Release cut: CHANGELOG + tag + GH release | Sonnet | medium | Multi-step with side-effects, mechanical once spec'd |
| Retro / dogfood write-up | Sonnet | medium | Read existing artifacts + categorize |
| Bootstrap / lifecycle test (`scripts/test-bootstrap.sh`) | Sonnet | low | Pure verification |

## /effort calibration (Claude Code specific)

- `/effort low` — single decision, no chain-of-thought needed (sed, simple commits, verifiers)
- `/effort medium` — default executor; multi-step with clear anchors
- `/effort high` — default planner; needs reasoning, recovers from ambiguous mid-stream signals
- `/effort xhigh` — architecture decisions, novel design problems with no precedent in this repo

## Other models — principle extension

Tandem's interface is markdown. The model selection principle generalizes:

- **Reasoning-strong → planner role.** Claude Opus, OpenAI o-series, GPT-5 thinking, Gemini Pro thinking. Optimize for tradeoff analysis, not throughput.
- **Execution-strong → executor role.** Claude Sonnet, GPT-5 Codex, Gemini Flash. Optimize for speed + literalness. Literalness is a feature — it forces the planner to be explicit. If the executor misunderstands, the prompt was ambiguous.
- **Avoid for executor**: very small models. Literalness erodes; ambiguous prompts get re-interpreted creatively, which is the opposite of what you want.
- **`/effort` equivalents**: most non-Claude models don't expose an `/effort` knob. Substitute reasoning effort / temperature / thinking-budget settings if available, otherwise accept default.

Pair selection is the principle. The specific model names are the implementation. Swap models without changing the workflow.

## Execution profile convention

Every inbox prompt should declare its profile near the top:

```markdown
## Execution profile

- model: sonnet
- effort: medium
- 3 commits + archive
```

The planner picks based on this guide. The executor reads the profile as confirmation of what was intended.

This is a soft convention — no lint, no hook. Bootstrapped projects get a comment block in `templates/prompts/_inbox.md` reminding to add it. See [docs/REFERENCE.md](REFERENCE.md) for the convention row.

## Why empirical, not theoretical

Anthropic's official model selection guidance is generic and version-shifting. Tandem's recommendations come from actually shipping inbox rounds and observing which combinations did and didn't work. When a recommendation is wrong, an inbox round will fail — and that's the signal to update this file.

If you fork Tandem and your task profile differs (different domains, different models), edit your fork's `MODEL_GUIDE.md`. The point is the table reflects *your* workflow, not mine.
