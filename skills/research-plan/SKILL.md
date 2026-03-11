---
name: research-plan
description: Builds a prioritized research plan with topic-to-connector mapping from project-context.md. Use when open questions or tech decisions need evidence before building.
disable-model-invocation: true
---

# research-plan

Analyze the project context, existing code, and any prior research. Produce a
prioritized research plan that maps every topic to specific research connectors.
The plan becomes the input to `research-execute`.

## When to use

- After `project-context.md` is written and there are open questions or
  unvalidated tech choices.
- User says "research plan", "what needs researching", or "plan the research."
- The project involves a domain the team is not deeply expert in.
- Tech stack decisions were made on gut feeling and need evidence.

## Inputs

| Input | Source | Required |
|---|---|---|
| project-context.md | Project root | Yes |
| Existing code | `src/` directory | No |
| Prior research | Artifact DB (`research-plan` / `plan`) | No |

## Instructions

1. **Read all inputs.** Start with `project-context.md` — it is the primary
   source. Then scan `src/` for existing code patterns that might inform
   research needs (e.g., a half-built auth system suggests researching auth
   patterns). Check the artifact DB for prior research runs:
   `source artifacts/db.sh && db_read_all 'research-plan' 'plan'`. Use
   `db_search` to find any existing work on overlapping topics.

2. **Extract research topics.** Pull topics from these sources:
   - **Open Questions** in project-context.md — each one is a potential topic.
   - **Key Decisions** where alternatives were not deeply evaluated.
   - **Tech Stack** choices that lack evidence (e.g., "chose Postgres" but no
     comparison with alternatives for the specific use case).
   - **Architecture Overview** — any component where the design is uncertain.
   - **Gaps you notice** — things the context doc doesn't address but should
     (security model, scaling strategy, error handling patterns, etc.).

3. **Categorize each topic.** Every topic falls into one of three lanes:

   | Lane | What it covers | Connectors |
   |---|---|---|
   | Academic | Papers, studies, clinical data, formal research | Consensus, Scholar Gateway, Synapse.org, PubMed, Clinical Trials |
   | Code | Libraries, frameworks, implementation patterns, docs | Context7, GitHub (API), Microsoft Learn |
   | Both | Topics needing evidence + implementation examples | Hugging Face, Web Search |

   Assign each topic to a lane. A single topic can use multiple connectors
   within its lane.

4. **Map topics to connectors.** For each topic, list the specific connectors
   to query and draft the query intent (not the exact API call — that's
   `research-execute`'s job). Example:

   ```
   Topic: "Best auth pattern for multi-tenant SaaS"
   Lane: Both
   Connectors:
     - Web Search: "multi-tenant authentication patterns 2025"
     - Context7: auth library documentation
     - GitHub: search for reference implementations
   Priority: P0 (blocks architecture)
   ```

5. **Prioritize.** Rank topics:
   - **P0** — Blocks progress. Cannot design or build without this answer.
   - **P1** — Important. Affects quality or correctness of the build.
   - **P2** — Nice to have. Improves the project but not blocking.

   Sort the plan by priority. `research-execute` will process P0 topics first.

6. **Self-counter.** Before presenting the plan, challenge it:
   - Are any topics too broad? ("Research databases" is useless — "Compare
     Postgres vs. DynamoDB for time-series IoT data at 10K writes/sec" is
     actionable.)
   - Are any topics already answered by the existing code or context doc?
   - Are there topics missing that the project obviously needs?
   - Does every topic have at least one mapped connector, or are some orphaned?

   Revise the plan based on your own critique.

7. **Determine NNN and prepare the summary directory.** NNN is determined by
   counting existing `research-plan` records in the DB:

   ```bash
   source artifacts/db.sh
   NNN=$(printf '%03d' $(( $(sqlite3 artifacts/project.db "SELECT COUNT(*) FROM artifacts WHERE skill='research-plan' AND phase='plan';" 2>/dev/null || echo 0) + 1 )))
   ```

   Only create `artifacts/research/summary/` directory (needed for the final
   synthesis file). No numbered subfolder is created — all intermediate files
   go to the DB.

8. **Write the plan.** Store in the artifact DB:

   ```bash
   source artifacts/db.sh
   db_upsert 'research-plan' 'plan' '{NNN}' "$PLAN_CONTENT"
   ```

   The NNN label identifies this research run throughout the pipeline.
   Structure the plan content as:

   ```markdown
   # Research Plan — {{PROJECT_NAME}}

   Generated: {{date}}
   Research run: {NNN}
   Source: project-context.md

   ## Summary
   - Total topics: N
   - P0: N | P1: N | P2: N
   - Connectors needed: [list]

   ## Topics

   ### [P0] Topic Name
   **Question:** What specifically needs answering?
   **Lane:** Academic | Code | Both
   **Connectors:** [list with query intent for each]
   **Why it matters:** How this blocks or affects the project.

   [repeat for each topic]

   ## Connector Allocation
   [Table mapping each connector to the topics it will serve — this becomes
   the dispatch table for research-execute]
   ```

9. **Present for approval.** Show the user the plan. Ask if the priorities are
   right, if any topics are missing, and if the scope is acceptable. Research
   takes time and tokens — the user should approve the investment.

## Exit condition

The research plan is stored in the artifact DB (`research-plan` / `plan` / `{NNN}`)
with all topics categorized, prioritized, and mapped to connectors. The plan has been
self-countered. The user has approved the scope.

Verify: `source artifacts/db.sh && db_exists 'research-plan' 'plan' '{NNN}'`

## Examples

```
User: "What do we need to research before building?"
Action: Read project-context.md, extract topics, categorize, map to
        connectors, self-counter, write research_plan.md, present for
        approval.
```

```
User: "Create a research plan for the ML pipeline project"
Action: Read project-context.md for the ML pipeline. Extract topics like
        model serving frameworks, data pipeline patterns, GPU hosting options.
        Map to Hugging Face (models), Context7 (framework docs), Web Search
        (hosting comparisons), Scholar Gateway (recent papers on the
        technique).
```

```
User: "We already did some research, plan what's left"
Action: Read existing plans from artifact DB (db_read_all 'research-plan' 'plan'),
        use db_search for overlapping topics, cross-reference with project-context.md
        open questions, identify gaps, plan only the remaining topics.
```

## Cross-cutting

Before completing, read and follow `../references/cross-cutting-rules.md`.
