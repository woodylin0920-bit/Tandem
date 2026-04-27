# Attribution

## Origin: omni-sense

Tandem was extracted from **omni-sense**, an offline accessibility-focused navigation pipeline I shipped in one week as a solo developer using Claude Code.

That sprint forced the workflow into a working shape: two parallel Claude sessions (one planning, one executing), a file-based handoff (`_inbox.md`), atomic phase commits, codex cross-vendor audits, and pre-ship safety gates. Six P0 issues surfaced via codex audit after Phase 1 was "done" — that incident is why phase-gate exists at all.

Rather than re-invent the workflow on every new project, I pulled the scaffolding out into a reusable framework. That framework is Tandem.

## What carried over

- Plan/execute session split with `_inbox.md` handoff
- Codex cross-vendor audit conventions (`templates/prompts/CODEX_AUDIT.md`)
- Phase-gate ship discipline (tests + SLO + clean push state)
- Real-machine smoke testing (`templates/scripts/smoke.sh`)
- Accessibility / safety audit prompt template (`templates/prompts/SAFETY_AUDIT.md`) — kept available as a nice-to-have for projects that need it; not part of Tandem's core wedge

## What did NOT carry over

- Domain-specific code (audio cues, OCR, navigation logic) — those belonged to omni-sense, not the framework
- omni-sense-specific memory entries — Tandem's memory templates are intentionally generic
- "Accessibility-first" positioning — Tandem's positioning is workflow framework for solo engineers, not accessibility tooling
