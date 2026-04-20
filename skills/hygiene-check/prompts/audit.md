# Sonnet-4.6 audit prompt — STUB

> This file is a placeholder. The actual audit prompt is Phase 2 of the build plan and hasn't been written yet.
> Authoritative plan: `artifacts/plans/hygiene-check-skill.md`.
> Pipeline phase: `project_call > get_plan {plan_slug: "hygiene-check-skill-build"}` phase 2.

## Why this is a stub

The inbox #74 assignment author (dell-xps session, 2026-04-17) was explicit: *"Model: sonnet-4.6 (not opus). Cheap, fast, good at structured comparison. Prompt engineering: tight, no ambiguity. Give the sonnet agent the exact invariants, the exact search queries to run, the exact output template. No room for 'interpret the spirit.'"*

Prompt engineering of that quality benefits from fresh context rather than being written at the tail of a long session. Intentionally deferred.

## Input spec (when the prompt gets written)

The prompt should receive:
- `project_slug` — which project to audit
- `invariants` — the list from `artifacts/plans/hygiene-check-skill.md` (refreshed for post-2026-04-20 structure)
- `output_template` — the exact report format (see SKILL.md)

For each invariant, the prompt should specify:
- The exact MCP tool calls to make (memory_call query strings, graph_call lookups, artifact DB queries)
- The evaluation rule (what counts as PASS, FLAG, INFO)
- The suggested-fix language for FLAG cases

## Output spec

A single structured report, under 400 words, following the SKILL.md template exactly. No prose outside the template. No extra reasoning dumps.

## Write this prompt when

Phases 1 and 3 are complete (both done). Phase 2 (this file) can start in any future session with fresh context. It unblocks Phases 4 and 5 (testing).
