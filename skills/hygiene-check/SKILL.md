---
name: hygiene-check
description: "Audits whether agent work is landing in all persistence stores correctly for the current project. Audit-only, no auto-fix. Spawns a sonnet-4.6 sub-agent to run the audit in a separate context — breaks the 'report clean without checking' failure mode. Triggers on 'hygiene check', 'audit memory', 'is everything persisted', 'pre-phase-close audit', and explicit /hygiene-check."
---

# hygiene-check

> **Status: scaffolded 2026-04-20 — prompt template and testing phases not yet complete.**
> Authoritative plan: `artifacts/plans/hygiene-check-skill.md` in the claude-skills-suite repo.
> Pipeline: `project_call > get_plan {plan_slug: "hygiene-check-skill-build"}` (plan id 8).
> Closes: interagent inbox #74.

## What this skill does

Audits the current project's persistence state across Qdrant, Neo4j, the artifact DB, and the engineering notebook. Confirms that decisions, findings, and structural changes made in recent sessions have been persisted where they should be. Returns a structured report the driving session reviews and acts on.

**Audit-only. No auto-fix. No continuous monitoring.**

Invocation launches a **sonnet-4.6 sub-agent** with a tight audit prompt. The sub-agent runs in its own context window, which is the point: a different context + a different judgment call catches things the driving session missed.

## When to use

- **Recommended before any phase close-out** — before marking a phase completed in notebook or pipeline, before `interagent_call > complete` on a phase assignment.
- **Session end** — as part of store-summary action items.
- **On-demand** — user types `/hygiene-check` or a natural trigger: "audit memory", "is everything persisted", "pre-phase-close check".

## Invariants audited

See `artifacts/plans/hygiene-check-skill.md` for the current list with reasoning. Summary as of 2026-04-20:

1. Qdrant dual-write for decisions (Qdrant memory ↔ artifact DB row)
2. Artifact DB coverage for recent decision-type memories
3. Neo4j observation coverage for structural-entity decisions
4. Engineering notebook staleness vs recent activity
5. Contradictions — old memories vs current file tree / git log
6. Long-arc artifacts present (`artifacts/plans/current.md`, `artifacts/project.db`, GOTCHAS.md if applicable; no PROGRESS.md / CURRENT-STATE.md / PLAN-\*.md at root)

## How the skill works (high level)

1. Detect the current project — rehydrate with the CWD's slug, or read GROUNDING.md for a `project_slug:` frontmatter line. If neither works, ask the user.
2. Spawn a sonnet-4.6 sub-agent with the audit prompt at `skills/hygiene-check/prompts/audit.md` (when that file is complete).
3. Pass the project slug, the list of invariants, and the output template to the sub-agent.
4. Return the sub-agent's structured report to the driving session.

## Output format

```
## Hygiene Report — <project-slug> — <timestamp>

### PASS
- <invariant>: <one line describing what was checked>

### FLAG
- <invariant>: <specific issue> — suggested fix: <action>

### INFO
- <optional observations>

Summary: N passes, M flags, K info. <one-line recommendation>
```

Report length: under 400 words.

## Non-goals

- No auto-fix. Agent flags, driving session decides.
- No continuous monitoring / polling.
- No silent memory rewrites.
- No cross-channel posting (Mattermost, email, ntfy). Output goes to invoking session only.

## Current scaffold state (2026-04-20)

**Complete:**
- Skill directory and SKILL.md skeleton (this file)
- Invariant list refreshed for post-2026-04-20 long-arc structure
- Pipeline plan 8 created with 6 phases
- Authoritative plan doc at `artifacts/plans/hygiene-check-skill.md`

**Not yet done (deferred to future session for fresh context):**
- `prompts/audit.md` — the sonnet-4.6 audit prompt template. Stub file exists. Needs careful prompt engineering with no ambiguity.
- Phase 4: Test against clean state (requires QL-G3-Enterprise migration first)
- Phase 5: Test against broken state (intentional breakage + audit verification)
- Phase 6: Documentation + close-out

## Usage note

**This skill is not functional yet.** Invoking `/hygiene-check` currently lands on this scaffold without a working audit prompt. Do not rely on it for actual hygiene auditing until Phases 2, 4, and 5 complete.
