---
name: build-plan
description: Generates project-plan.md with phases, milestones, technical approach, and parallelizable work units. Use when moving from research/context into implementation planning.
---

# build-plan

Take GROUNDING.md (or project-context.md) and produce a comprehensive project plan.
Decomposes the project into phases, milestones, and individual work units tagged for
parallel or sequential execution.

## When to use

- User is ready to plan the build after context/research is complete
- User says "build plan", "project plan", "plan the build", "plan it out"
- GROUNDING.md exists and user wants to move to implementation

## Inputs

| Input | Source | Required |
|---|---|---|
| GROUNDING.md or project-context.md | Project root | Yes |
| Research synthesis (if available) | Prior research output | No |

## Instructions

1. **Read all inputs.** Start with GROUNDING.md — it defines what to build, for whom,
   and under what constraints. Read research synthesis if it exists. If no research
   was done, note it and proceed — the plan will be less evidence-backed but functional.

2. **Define phases.** Break the project into 3-6 phases. Each delivers something usable
   or testable — no purely preparatory phases with no visible output. Typical pattern:

   - **Phase 1: Foundation** — Core data model, setup, basic API/skeleton
   - **Phase 2: Core features** — The primary value proposition
   - **Phase 3: Integration** — External systems, auth, real data
   - **Phase 4: Polish** — Error handling, edge cases, performance
   - **Phase 5: Ship** — Deployment, monitoring, docs

   Adapt to the project. Some need a research spike first. Others skip integration.

3. **Set milestones.** Each phase gets 1-2 milestones. Concrete, testable:
   "User can log in and see their dashboard" not "Auth is done."

4. **Decompose into work units.** Each work unit:

   | Field | Description |
   |---|---|
   | ID | `WU-<phase>-<seq>` (e.g., WU-1-03) |
   | Title | Short descriptive name |
   | Description | What this unit delivers (1-3 sentences) |
   | Dependencies | List of WU IDs that must complete first |
   | Parallelizable | `yes` or `no` |
   | LOC estimate | Target **50-200 LOC** across 2-5 files. >200 must be split. |
   | Key files | Files created or modified. Two parallel units must NOT modify the same file. |
   | Acceptance criteria | Pass/fail checks, not vague descriptions |

   **Sizing rule**: Can't describe in 1-3 sentences with clear criteria? Too big. Split it.
   Touches >5 files? Too broad. Narrow it.

   **No-placeholders rule**: Every work unit must be fully implementable as specified. Reject:
   - "wire up later", "placeholder for now", "TBD"
   - Deferred integration without naming the consuming unit by ID
   - Exports without specifying who consumes them
   - Resource acquisition without specifying cleanup

5. **Map dependencies.** Draw the dependency graph (text DAG or table). Identify the
   critical path — longest chain of sequential work units.

6. **Identify risks.** For each: what could go wrong, likelihood, impact, mitigation.

7. **Define technical approach.** For each major component (auth, data layer, API, UI),
   describe the approach in 3-5 sentences.

8. **Integration wiring audit.** Before presenting, verify:
   - Every unit that creates an export names consuming unit(s) by ID
   - Every env var/config key introduced is consumed within same wave or carried as dependency
   - Every resource opened has cleanup in acceptance criteria
   - No "placeholder", "TBD", "wire later" language

9. **Write the plan.** Save to `project-plan.md` in the project root:

   ```markdown
   # Project Plan — {{PROJECT_NAME}}

   Generated: {{date}}
   Based on: GROUNDING.md

   ## Executive Summary
   ## Phases and Milestones
   ## Technical Approach
   ## Work Units
   ## Dependency Graph
   ## Risks
   ## Open Items
   ```

10. **Present for approval.** Show summary (phases, milestone count, total work units,
    critical path length, top risks). The user knows their domain better than any model.

11. **Revise if needed.** Re-run integration wiring audit after revisions.

## Exit condition

`project-plan.md` exists. All phases have milestones. All work units have dependencies
mapped and parallelism tagged. Risks identified. User approved.

## Examples

```
User: "Plan the build"
→ Read GROUNDING.md. Define phases, milestones, work units. Write project-plan.md. Present for approval.
```

```
User: "Create a project plan — we didn't do research"
→ Note research was skipped. Plan from GROUNDING.md alone. Flag gaps as risks.
```

```
User: "Keep it to 3 phases — small project"
→ Condense. Combine related work units. Respect the user's scope calibration.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
