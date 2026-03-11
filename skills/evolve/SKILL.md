---
name: evolve
description: "Update living project documents when state changes. Use for evolving context, plan, or both. Triggers on evolve, update docs, sync docs, project changed."
argument-hint: "[context — just context, plan — just plan, or describe what changed for both]"
---

# Evolve

Update project-context.md, project-plan.md, or both to reflect current truth. Three modes:

- `/evolve context [what changed]` — update only project-context.md
- `/evolve plan [what changed]` — update only project-plan.md
- `/evolve [what changed]` — full chain: optional research → discussion → context → plan → cross-check

## Instructions

### Mode Detection

Parse the user's argument:
- Starts with `context` → Context-only mode
- Starts with `plan` → Plan-only mode
- Anything else → Full mode (both documents)

---

### Context-Only Mode

1. **Read current project-context.md.** If it doesn't exist, stop — tell user to run `/meta-init` first.

2. **Identify what changed.** Compare new information against current document. List every field that needs updating.

3. **Edit sections in place.** Update affected fields directly so the body shows current truth. Keep same structure and formatting — change values, not layout.

4. **Build changelog entry.** Read format from `../../references/evolve-context-diff.md`. For each changed field:
   - Field changes: `**[Section]: [Field]**: "[old]" -> "[new]"`
   - Key Decision added/changed/removed: note row number and content
   - Reason: one line explaining why

5. **Insert changelog at top** (newest first, append-only). Use today's date and platform (`CLAUDE`/`CODEX`/`GEMINI`/`COPILOT`).

6. **Verify completeness.** Every changed field in the body must have a corresponding "was → now" line. Missing entries = lost history.

---

### Plan-Only Mode

1. **Read current project-plan.md.** If it doesn't exist, stop — tell user to run `/meta-init` first.

2. **Identify what changed.** Determine which work units were completed, added, removed, re-scoped, or had dependency changes.

3. **Edit sections in place.** Update affected work units directly:
   - Mark completed work as done
   - Add new work units in appropriate phase
   - Update dependency chains
   - Adjust scope descriptions
   - Move work between phases if sequencing changed

4. **Build changelog entry.** Read format from `../../references/evolve-plan-diff.md`. For each change:
   - Completed: `[work unit] — [brief outcome]`
   - Added: `[work unit] — [why needed]`
   - Changed: `[work unit] — "[old]" -> "[new]"`
   - Removed: `[work unit] — [why no longer needed]`
   - Blocker added/resolved: `[work unit] depends on / unblocked by [what]`
   - Reason: one line for overall rationale

5. **Insert changelog at top** (newest first, append-only).

6. **Verify completeness.** Every status change must have a corresponding changelog line.

---

### Full Mode

#### Phase 0: Research Gate (Optional)

Assess whether the change involves unfamiliar territory — new technology, domain shift, unclear tradeoffs.

**Trigger research if ANY are true:**
- Change introduces technology/pattern not in the project's stack
- User describes a problem but doesn't have a clear solution
- You lack confidence in the best approach
- Change affects multiple architectural concerns with unclear tradeoffs

**Skip research if ALL are true:**
- Change is straightforward (completed work, scope cut, simple swap)
- Technologies are already well-understood in this project
- User has already made the decision

If research needed: Ask user, then run `/meta-research` scoped tightly to the change. P0-only mode unless broader coverage requested.

#### Phase 0.5: Informed Discussion

After research (or if the change has multiple valid approaches):

1. **Summarize** what you learned relevant to the change
2. **Present options** if tradeoffs exist:
   - Option A: [approach] — [pros] — [cons]
   - Option B: [approach] — [pros] — [cons]
   - Recommendation: [which and why]
3. **Surface risks**: implications the user may not have considered, conflicts with existing Key Decisions
4. **Get explicit approval** before updating docs

Skip this phase if the user made a clear, unambiguous decision and just wants docs updated.

#### Phase 1: Evolve Context

Run the Context-Only Mode instructions above.

**Transition**: If the change only affected context (e.g., glossary update, constraint clarification) with zero plan impact, tell the user and exit. Otherwise proceed.

#### Phase 2: Evolve Plan

Run the Plan-Only Mode instructions above. Pass any new context from Phase 1 (e.g., Key Decision changes affecting dependencies).

#### Phase 3: Cross-Check Consistency

After both phases complete:

1. **Verify no contradictions** between project-context.md and project-plan.md:
   - Context says tech stack X, plan has work units for Y?
   - Context says feature out of scope, plan has work units for it?
   - Context says constraint exists, plan ignores it?

2. If inconsistencies found, flag to user and ask which document is correct. Fix before exiting.

3. **Present summary**: files modified, fields updated, work units affected, research incorporated, inconsistencies resolved.

## Why This Format

project-context.md and project-plan.md serve two audiences each: someone who wants current state (reads the body) and someone who wants the decision trail (reads the changelog). Edit-in-place keeps the body authoritative. Changelog-as-diff preserves history without cluttering the body.

## Examples

```
User: "We switched from REST to GraphQL. Update the docs."
Mode: Full. Phase 0 — GraphQL is new, ask to research. Phase 0.5 — present
schema-first vs code-first. Phase 1 — update tech stack, architecture, Key
Decisions. Phase 2 — update work units. Phase 3 — cross-check.
```

```
User: "WU-4 is done and we discovered we need a migration script."
Mode: Full (both docs affected). Skip Phase 0/0.5 (straightforward). Phase 1 —
update Current State. Phase 2 — mark WU-4 complete, add migration work unit.
```

```
User: "/evolve context — we're removing mobile from scope, web only."
Mode: Context-only. Update scope/platform, remove mobile Key Decision. Changelog.
```

```
User: "/evolve plan — WU-3 done, auth middleware working with JWT."
Mode: Plan-only. Mark WU-3 complete. Changelog.
```

```
User: "Dropped the admin panel from MVP."
Mode: Full. Skip research. Phase 1 — update scope. Phase 2 — remove admin work
units, update dependencies. Flag if other features depended on it.
```

---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
