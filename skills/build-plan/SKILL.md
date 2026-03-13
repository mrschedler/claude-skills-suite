---
name: build-plan
description: Generates project-plan.md with phases, milestones, technical approach, and parallelizable work units. Use when moving from research/context into implementation planning.
---

# build-plan

Take the project context and research synthesis (if available) and produce a
comprehensive project plan. The plan decomposes the project into phases,
milestones, and individual work units tagged for parallel or sequential
execution.

## When to use

- Research is complete (or skipped) and the user is ready to plan the build.
- User says "build plan", "project plan", "plan the build", "plan it out."
- `project-context.md` exists and the user wants to move to implementation.

## Inputs

| Input | Source | Required |
|---|---|---|
| project-context.md | Project root | Yes |
| /artifacts/research/research_synthesis.md | research-execute output | No (plan from context alone if absent) |
| plan-template.md | Bundled in `templates/` beside this skill | Yes |

## Instructions

1. **Read all inputs.** Start with `project-context.md` — it defines what to
   build, for whom, and under what constraints. Then read
   `research_synthesis.md` if it exists — it provides evidence for tech choices
   and flags risks. If research was not run, note it and proceed from context
   alone. The plan will be less evidence-backed but still functional.

2. **Competitive landscape check.** Load `/gemini` for invocation syntax.
   Key params: 120s timeout, prompt: `"For a project described as: [one-line
   summary from context]. List the top 5 competing or similar projects/products.
   For each: name, what it does, strengths, weaknesses, and what this project
   could learn from it. Bullet points only."`. Output to
   `/tmp/competitive-landscape.md`.
   Read the output and incorporate relevant insights into the plan (especially
   "lessons learned" and "differentiation"). If Gemini is unavailable or fails,
   retry with Copilot — load `/copilot` for invocation syntax. Same prompt,
   same output file. If both fail, skip and note it.

3. **Technical feasibility check.** Load `/codex` for invocation syntax.
   Key params: `--sandbox read-only`, `--ephemeral`, `--cd /tmp`, 120s timeout.
   Prompt: `"Given this tech stack: [stack from context]. And this scope:
   [scope summary]. Flag any technical risks: library maturity issues, known
   scaling problems, integration pain points, or missing pieces. Be specific."`.
   Output to `/tmp/feasibility-check.txt`.
   Read the output and factor risks into the plan. If Codex is unavailable,
   skip and note it.

4. **Define phases.** Break the project into 3-6 phases. Each phase should
   deliver something usable or testable — avoid phases that are purely
   preparatory with no visible output. Typical phase pattern:

   - **Phase 1: Foundation** — Core data model, project setup, basic API or
     skeleton.
   - **Phase 2: Core features** — The primary value proposition. What makes
     this project worth existing.
   - **Phase 3: Integration** — Connect to external systems, auth, real data.
   - **Phase 4: Polish** — UI refinement, error handling, edge cases,
     performance.
   - **Phase 5: Ship** — Deployment, monitoring, documentation, launch.

   Adapt this pattern to the specific project. Some projects need a research
   spike as Phase 1. Others can skip integration. Match the phases to the
   actual work.

5. **Set milestones.** Each phase gets 1-2 milestones. A milestone is a
   concrete, testable statement: "User can log in and see their dashboard" not
   "Auth is done." Milestones are the checkpoints that tell the user (and
   future agents) whether the project is on track.

6. **Decompose into work units.** Within each phase, break the work into
   discrete units sized for AI worker execution. Each work unit includes:

   | Field | Description |
   |---|---|
   | ID | `WU-<phase>-<seq>` (e.g., WU-1-03) |
   | Title | Short descriptive name |
   | Description | What this unit delivers (1-3 sentences) |
   | Dependencies | List of WU IDs that must complete first |
   | Parallelizable | `yes` or `no` — can this run alongside other units? |
   | LOC estimate | Target **50-200 LOC** across 2-5 files. Units >200 LOC must be split. (SWE-bench data: success drops from 74% to 11% on multi-commit features.) |
   | Key files | Files this unit creates or modifies. Two parallel units must NOT modify the same file. |
   | Acceptance criteria | Verifiable criteria — each unit must produce at least one testable export. Write criteria as pass/fail checks, not vague descriptions. |

   **Sizing rule**: If a unit can't be described in 1-3 sentences with
   clear acceptance criteria, it's too big. Split it. If it touches >5
   files, it's too broad. Narrow it.

   **No-placeholders rule (MANDATORY)**: Every work unit must be fully
   implementable as specified. Reject any work unit that:
   - Uses "wire up later", "placeholder for now", "TBD", or "to be determined"
   - Defers integration to a future unit without naming that unit by ID
   - Describes an output without specifying who consumes it
   - Creates exports, config keys, or env vars without stating where they're read
   - Acquires resources (DB, PTY, WebSocket) without specifying cleanup

   If a unit can't be fully wired in isolation, split it differently or
   merge it with the consuming unit. The goal: every unit's output is
   connected to a consumer by the end of the same wave.

   Tag work units as parallelizable when they have no mutual file
   dependencies. This enables multi-agent execution via meta-execute —
   workers run in parallel on isolated worktrees.

7. **Map dependencies.** Draw the dependency graph (as a text-based DAG or
   table). Identify the critical path — the longest chain of sequential work
   units. This determines the minimum project duration regardless of
   parallelism.

8. **Identify risks.** Pull from research synthesis, feasibility check, and
   your own analysis. For each risk:
   - What could go wrong.
   - Likelihood (high/medium/low).
   - Impact (high/medium/low).
   - Mitigation strategy.

9. **Define the technical approach.** For each major component (auth, data
   layer, API, UI, etc.), describe the approach in 3-5 sentences. Reference
   research findings where applicable. This is not full architecture docs — it
   is enough for an agent to start implementing without guessing at the
   overall strategy.

10. **Write the plan.** Use `templates/plan-template.md` as the skeleton. Save
    to `project-plan.md` in the project root. Structure:

    ```markdown
    # Project Plan — {{PROJECT_NAME}}

    Generated: {{date}}
    Based on: project-context.md, research_synthesis.md

    ## Executive Summary
    [3-5 sentences: what, how many phases, key risks, estimated total effort]

    ## Phases and Milestones
    [Phase table with milestones and target dates if timeline is known]

    ## Technical Approach
    [Per-component approach descriptions]

    ## Work Units
    [Full table of all work units with all fields]

    ## Dependency Graph
    [Text DAG or table showing unit dependencies and critical path]

    ## Risks
    [Risk table with likelihood, impact, mitigation]

    ## Competitive Insights
    [Key takeaways from landscape analysis, if available]

    ## Open Items
    [Anything unresolved that needs user input before work begins]
    ```

11. **Integration wiring audit.** Before presenting the plan, verify:
    - Every work unit that creates an export names the consuming unit(s) by ID.
    - Every env var or config key introduced by a unit is consumed within the same
      wave or explicitly carried forward as a dependency.
    - Every resource opened by a unit (DB, PTY, event bus, WebSocket) has cleanup
      specified in that unit's acceptance criteria.
    - No work unit uses "placeholder", "TBD", "wire later", or deferred language.
    If any violations are found, fix them before presenting. This prevents the
    "code exists but isn't connected" failure mode that plagues multi-agent builds.

12. **Present for approval.** Show the user the plan summary (phases,
    milestone count, total work units, critical path length, top risks). Ask
    if priorities are correct, if anything is missing, and if effort estimates
    feel right. The user knows their domain better than any model — their
    calibration matters.

13. **Revise if needed.** If the user requests changes, update the plan and
    re-present. Re-run the integration wiring audit (step 11) after revisions.
    Do not write the final file until approved.

## Exit condition

`project-plan.md` exists in the project root. All phases have milestones. All
work units have dependencies mapped and parallelism tagged. Risks are
identified. The user has approved the plan.

### Optional: Skeleton Generation (Codex)

After the user approves the plan, offer to generate skeleton files:

> "Plan approved. Want me to generate skeleton files (interfaces, types, module stubs) for the work units? This gives implementation a head start."

If yes:
1. Load `/codex` for invocation syntax. If Codex is unavailable, skip.
2. If available, for each work unit that creates new files, dispatch a Codex
   worker. Key params: `--sandbox workspace-write`, `--ephemeral`,
   `--cd <project-root>`, 180s timeout.
   Prompt: `"Generate skeleton files for this work unit. Create the file
   structure with interfaces, type definitions, function signatures (with TODO
   bodies), and module exports. Do NOT implement business logic — just the
   structure. Work unit: [DESCRIPTION] Tech stack: [FROM PROJECT CONTEXT]
   Files to create: [FROM PLAN]"`.
3. If Codex is unavailable, skip — this is a convenience step, not required.

## Examples

```
User: "Plan the build"
Action: Read project-context.md and research_synthesis.md. Run competitive
        landscape (Gemini) and feasibility check (Codex) in parallel.
        Define phases, milestones, work units. Write project-plan.md.
        Present summary for approval.
```

```
User: "Create a project plan — we didn't do research"
Action: Note that research was skipped. Read project-context.md only. Skip
        research-dependent sections. Flag areas where research would have
        helped (add them as risks). Proceed with planning.
```

```
User: "Build plan, but keep it to 3 phases — this is a small project"
Action: Condense to 3 phases. Reduce work unit granularity — combine small
        related units. Keep milestones and dependencies. Respect the user's
        calibration on scope.
```

```
User: "We need to re-plan — scope changed after phase 1"
Action: Read existing project-plan.md and project-context.md. Ask what
        changed. Rewrite phases 2+ while preserving completed phase 1.
        Update dependencies and re-assess risks.
```

## Cross-cutting

Before completing, read and follow `../references/cross-cutting-rules.md`.
