---
name: meta-research
description: "End-to-end research pipeline: plan then execute. Trigger for full research flow — from project context through countered synthesis. For research this project, do all the research, full research."
---

# meta-research

Meta-skill that chains both research atomic skills in order, taking a project
from open questions to a countered, evidence-backed synthesis.

The main chat context stays lean — all heavy research work happens in a
dispatched Opus subagent.

## Chain

```
research-execute Phase 0 (plan) -> [approval gate] -> write prompt -> dispatch Opus -> present results
```

## Inputs

| Input | Source | Required |
|---|---|---|
| project-context.md | Project root | Yes |
| Existing code | `src/` directory | No |
| Prior research | `artifacts/research/` directory | No |

## Instructions

### Phase 1: Research Plan

Run Phase 0 (plan) of `../research-execute/SKILL.md`.

Analyze the project context, extract research topics, categorize by lane
(Academic / Code / Both), map to connectors, prioritize (P0/P1/P2), and
self-counter the plan.

**Exit condition**: `artifacts/research/{NNN}/research_plan.md` exists with all topics
categorized, prioritized, and mapped to connectors. The plan has been
self-countered. The user has approved the scope.

**Transition**: Proceed to Approval Gate.

### Approval Gate

Present this choice to the user:

> "Research plan is ready with N topics (P0: X | P1: Y | P2: Z).
>
> 1. **Execute all** — run every topic through its mapped connectors
> 2. **P0 only** — run only the blocking topics, skip P1/P2
> 3. **Cherry-pick** — tell me which topics to run
> 4. **Stop here** — keep the plan, execute later with `/research-execute`"

Wait for the user's answer. Do not assume.

- **Option 1**: Proceed to Phase 2 with the full plan.
- **Option 2**: Proceed to Phase 2 but filter to P0 topics only.
- **Option 3**: Ask the user which topic numbers to include, then proceed to
  Phase 2 with the filtered set.
- **Option 4**: Confirm the plan is saved and exit.

### Phase 2: Write Research Prompt

After approval, write `artifacts/research/{NNN}/research-prompt.md` — **max 200 lines**.
This file is the ONLY input the Opus subagent reads to understand the full
scope. Maximize conciseness without context loss.

**Schema:**

```markdown
# Research Prompt — {NNN}

## Scope Decision
[Which option the user chose: all / P0 only / cherry-pick (list)]

## Research Plan Reference
artifacts/research/{NNN}/research_plan.md

## Topics to Execute
[List each topic with its priority, lane, and mapped connectors — copied from
the approved plan, filtered per the user's scope decision]

## Project Context Summary
[Compressed relevant sections from project-context.md — first 3 sections max]

## Source Counting Target
Target: 300+ sources scanned across all connectors.
Each connector subagent must follow the multi-query protocol (3-5 queries per
topic) and include a Source Tally table in its output.

## Output Configuration
- Research folder: artifacts/research/{NNN}/
- Summary destination: artifacts/research/summary/{NNN}-{topic-slug}.md
- Source tally: artifacts/research/{NNN}/source-tally.md

## Special Instructions
[Any user-specified constraints, focus areas, or modifications from the
approval gate discussion]
```

### Phase 3: Dispatch Opus Subagent

Spawn exactly ONE Opus subagent. Read `agents/opus-orchestrator.md` for the
prompt template — fill in the absolute skill path, NNN, and topic slug.

Do NOT pass the full research protocol in the prompt — the subagent reads it
from the SKILL.md file. This keeps the dispatch lightweight.

### Phase 4: Present Results

When the Opus subagent completes:

1. Read `artifacts/research/summary/{NNN}-{topic-slug}.md`
2. Read `artifacts/research/{NNN}/source-tally.md`
3. Present the executive summary with source counts to the user
4. Highlight gaps and low-confidence areas
5. Flag any counter-arguments that need human judgment

Then offer next steps:

> "Research complete. **{N} sources scanned | {N} cited** across {N} connectors.
>
> 1. **Build the plan** — run `/build-plan` to create an implementation plan
>    informed by these findings
> 2. **Dive deeper** — re-run specific topics with different connectors or
>    broader queries
> 3. **Go deep** — run `/meta-deep-research` for exhaustive multi-model
>    adversarial research on a specific question
> 4. **Done for now** — stop here and use the findings when ready"

Wait for the user's answer. If they choose 1, tell them to run `/build-plan`.
If they choose 2, ask which topics and re-run Phase 2-3 for those topics only.
If they choose 3, suggest a research question for deep research.
If they choose 4, confirm and exit.

## Error Handling

- If `project-context.md` does not exist, tell the user to run
  `/project-context` or `/meta-init` first. Do not proceed without it.
- If prior research exists in `artifacts/research/`, detect it and ask the user whether
  to build on it or start fresh.
- If the Opus subagent fails or times out, read whatever intermediate files
  exist in `artifacts/research/{NNN}/` and present partial findings with the source
  tally so far.
- If the user already has a `research_plan.md`, ask whether to use the existing
  plan or create a new one. If using the existing plan, skip to Phase 2.

## Examples

```
User: "Research this project"
Action: Read project-context.md. Run research-plan to extract and prioritize
        topics. Present the approval gate. On approval, write research-prompt.md.
        Dispatch Opus subagent. Present summary with source counts when done.
```

```
User: "/meta-research"
Action: Same as above — full chain from plan to countered synthesis via Opus.
```

```
User: "Do all the research but only the critical stuff"
Action: Run research-plan. At the approval gate, auto-select option 2 (P0
        only) since the user indicated they want only critical topics. Confirm
        with the user before proceeding.
```

```
User: "We already have a research plan, just execute it"
Action: Detect existing research_plan.md. Confirm with the user. Skip to
        Phase 2 (write prompt + dispatch Opus) directly.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
