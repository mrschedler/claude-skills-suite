# /hygiene-check skill build — active plan

> Active as of 2026-04-20. Supersedes: none — initial plan.
> Pipeline: `project_call > get_plan {plan_slug: "hygiene-check-skill-build"}` (plan id 8, project `claude-skills-suite`)
> Closes: interagent inbox #74 (filed 2026-04-17 by dell-xps)

## Purpose

Build a `/hygiene-check` skill that audits whether agent work is landing in all the persistence stores correctly for a given project. Audit-only — no auto-fix, no continuous watch. Output is a structured report that the driving session reviews and acts on.

The skill spawns a **sonnet-4.6 sub-agent** with a tight audit prompt. Running the audit in a separate context breaks the "report clean without checking" failure mode that Entry 10's 5-iteration experiment documented. A different context window + a different judgment call catches things the driving session missed.

Concrete reproducer from 2026-04-17 on quicklinks-g3-enterprise: a session saved auto-memory files locally, updated MEMORY.md, and moved on. Qdrant dual-write was skipped. The user caught it manually. A hygiene check would have flagged it in 30 seconds. (Note: the specific auto-memory failure is now hook-blocked — see Entry 12 — but the broader class of "skipped persistence" remains worth auditing.)

## Invariants to audit (refreshed 2026-04-20)

The original inbox #74 assignment listed 7 invariants. Three changed because of today's long-arc structure decision (Entry 14).

**Keep (5 invariants):**

1. **Qdrant dual-write for decisions** — for each decision-type memory in the last N days, does a corresponding artifact DB row exist? Or vice versa? Flag missing pairs.
2. **Artifact DB coverage** — for each `type=decision` or `type=finding` Qdrant memory in the last 7 days in the project's category, is there a matching `artifacts/project.db` record? Flag misses.
3. **Neo4j observation coverage** — for decisions tagged with structural entity names, does the corresponding Neo4j node have an observation dated within 7 days? Use `graph_call > get_node`.
4. **Engineering notebook staleness** — if the project has ENGINEERING-NOTEBOOK.md, is the last entry within 14 days given recent commit/decision activity?
5. **Contradictions** — Qdrant memories older than 30 days whose claims contradict current file tree or git log. Flag.

**Drop (2 invariants):**

- ~~MEMORY.md index integrity~~ — auto-memory is now hook-blocked (Entry 12). The `~/.claude/projects/*/memory/` dirs are inert; MEMORY.md no longer reflects real state.
- ~~Pipeline sprint tasks ↔ PROGRESS.md ↔ git log~~ — PROGRESS.md is obsolete under Entry 14's long-arc structure. The cross-reference this tried to catch doesn't exist anymore.

**Add (1 invariant):**

6. **Long-arc artifacts present** — for long-arc projects (identified by having ENGINEERING-NOTEBOOK.md OR significant commit history OR pipeline entry with multiple phases), verify:
   - `artifacts/plans/current.md` exists (real file or symlink)
   - `artifacts/project.db` exists
   - GOTCHAS.md exists (if project has any gotcha-type memories in Qdrant)
   - No PROGRESS.md, CURRENT-STATE.md, or PLAN-\*.md at root (superseded pattern)

## Phases

See pipeline for phase status: `project_call > get_plan {plan_slug: "hygiene-check-skill-build"}`.

| # | Phase | Est hours | Status |
|---|-------|-----------|--------|
| 1 | Scaffold skill dir + SKILL.md skeleton | 1 | pending |
| 2 | Write sonnet-4.6 audit prompt template | 2 | pending |
| 3 | Refresh invariants list (this section) | 1 | pending (essentially done — this doc captures it) |
| 4 | Test against clean state (QL-G3-Enterprise post-migration) | 1 | pending |
| 5 | Test against broken state (each invariant, flag then restore) | 2 | pending |
| 6 | Document + commit + close inbox #74 + update behavioral-reminders | 1 | pending |

Total estimate: ~8 hours across multiple sessions.

## Scoped scaffold completed 2026-04-20

This session completed Phase 1 scaffold + Phase 3 invariant refresh (this doc). Deferred to next session:
- Phase 2: Sonnet prompt template (needs fresh context for careful prompt engineering)
- Phases 4, 5: Testing (requires QL-G3-Enterprise migration first, which is itself deferred)
- Phase 6: Close-out

The scaffolded skill at `skills/hygiene-check/SKILL.md` has a frontmatter-only placeholder and notes pointing at this plan doc. The `skills/hygiene-check/prompts/audit.md` is a stub with the input spec but no prompt body yet.

## Output format (the report the skill returns to the driving session)

```
## Hygiene Report — <project-slug> — <timestamp>

### PASS
- <invariant>: <one line describing what was checked>

### FLAG
- <invariant>: <specific issue> — suggested fix: <action>

### INFO
- <optional observations: counts, recent activity timestamps>

Summary: N passes, M flags, K info. <one-line recommendation>
```

Report length: under 400 words. The driving session reads the report and decides what to act on.

## Non-goals (explicit)

- **No auto-fix.** Agent flags, driving session acts.
- **No continuous monitoring.** Invoke on demand only.
- **No silent memory rewrites.** If the sub-agent thinks a memory is wrong, it flags; the driving session decides whether to update.
- **No cross-channel posting.** Output goes to the invoking session only. No Mattermost, no email, no ntfy.

## Invocation points (documented in the skill description)

1. **Recommended before any phase close-out** — before committing an ENGINEERING-NOTEBOOK entry marking a phase completed, before calling `project_call > update_phase status=completed`, before `interagent_call > complete` on a phase assignment.
2. **Session end** — hooks/session-end-summary.sh can suggest `/hygiene-check` as part of store-summary action items.
3. **On-demand** — `/hygiene-check` typed by the user, or natural-language triggers like "audit memory", "is everything persisted", "pre-phase-close check".

## Abort / pivot criteria

- If sonnet-4.6 sub-agent proves unreliable at the audit checklist (hallucinates flags, misses obvious breaches), consider opus-4.7 or a different cheaper-than-opus model. The assignment author specified sonnet-4.6 for cost reasons; stay there unless quality forces otherwise.
- If the invariants prove too project-specific (e.g. Neo4j observations only relevant for some projects), make the invariant list configurable via the skill's description or a project-level config rather than dropping checks.
- If the hook-block + structured-plan pattern eliminates enough classes of failure that a dedicated audit skill adds less value than expected, down-prioritize.

## Evidence / references

- Interagent inbox #74 (dell-xps → any, 2026-04-17, claimed + to-be-completed): full original assignment with reproducer
- Interagent inbox #93 (skip → any, 2026-04-20, completed): rehydrate filter fix that made audit result-reading reliable
- Skills-suite Entry 12 (auto-memory hook-block): why MEMORY.md integrity check is no longer needed
- Skills-suite Entry 14 (long-arc structure): why PROGRESS.md check is no longer needed, why plans/current.md check is added
- Qdrant search hint: "hygiene check skill invariants sonnet audit sub-agent"
- QL-G3-Enterprise reference project: `PROGRESS.md` + `artifacts/plans/bind-time-cache-architecture.md` demonstrate the long-arc pattern this skill audits for
