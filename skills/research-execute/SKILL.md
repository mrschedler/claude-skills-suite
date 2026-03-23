---
name: research-execute
description: "Plans and executes research: extracts topics from project-context.md, maps to connectors, fans out subagents, synthesizes, triple-counters. Triggers on research, run the research, plan the research."
disable-model-invocation: true
---

# research-execute

Full research pipeline: plan topics, map to connectors, fan out subagents,
synthesize findings, and counter with three model families. Subsumes the
former `research-plan` skill — planning is now Phase 0 of execution.

## When to use

- User says "research", "run the research", "plan the research", "execute research."
- After `project-context.md` is written and there are open questions.
- Dispatched by `/meta-research` via Opus subagent with a `research-prompt.md`.
- A plan already exists in the artifact DB — skip Phase 0 and execute.

## Inputs

| Input | Source | Required |
|---|---|---|
| project-context.md | Project root | Yes |
| Artifact DB: `research-plan` / `plan` / `{NNN}` | Prior plan (skip Phase 0 if exists) | No |
| Artifact DB: `research-execute` / `prompt` / `{NNN}` | meta-research dispatch (if Opus subagent) | No |
| Existing code | `src/` directory | No |
| Prior research | Artifact DB (`research-plan` / `plan`) | No |

## Source Counting Target

**Regular research target: 300+ sources scanned.**

Every connector subagent uses the multi-query protocol (3-5 queries per topic).
The orchestrator aggregates source tallies from all connector findings files and
reports the total. If the aggregate falls below 300 after the initial fan-out,
note the shortfall in the synthesis and flag thin connectors.

## Instructions

### Phase 0: Plan (skip if plan already exists)

Check for an existing plan:
```bash
source artifacts/db.sh
PLAN=$(db_read 'research-plan' 'plan')
```

If a plan exists and the user hasn't asked to re-plan, skip to Phase 1.
If `--plan-only` was specified or user said "plan the research", stop after
this phase and present the plan for approval.

**If no plan exists, build one:**

1. Read `project-context.md` — the primary source. Scan `src/` for code
   patterns that inform research needs. Check artifact DB for prior research.

2. **Extract research topics** from:
   - Open Questions in project-context.md
   - Key Decisions where alternatives weren't evaluated
   - Tech Stack choices lacking evidence
   - Architecture gaps you notice

3. **Categorize each topic** into lanes:

   | Lane | Connectors |
   |---|---|
   | Academic | Consensus, Scholar Gateway, Synapse.org, PubMed, Clinical Trials |
   | Code | Context7, GitHub, Microsoft Learn |
   | Both | Hugging Face, Web Search |

4. **Map topics to connectors** with query intent for each.

5. **Prioritize**: P0 (blocks progress), P1 (affects quality), P2 (nice to have).

6. **Self-counter**: Are topics too broad? Already answered? Missing obvious needs?

7. **Determine NNN and store**:
   ```bash
   source artifacts/db.sh
   NNN=$(printf '%03d' $(( $(sqlite3 artifacts/project.db "SELECT COUNT(*) FROM artifacts WHERE skill='research-plan' AND phase='plan';" 2>/dev/null || echo 0) + 1 )))
   db_upsert 'research-plan' 'plan' "$NNN" "$PLAN_CONTENT"
   ```

8. **Present for approval.** Show the plan. Wait for user to approve scope.
   If `--plan-only`, stop here.

### Phase 1: Read the Plan

Read the research plan from the artifact DB:
`source artifacts/db.sh && PLAN=$(db_read 'research-plan' 'plan' '{NNN}')`.
If NNN is not yet determined, use `db_read 'research-plan' 'plan'` (fetches
most recent). Parse the plan content to extract topics, connector allocation,
and NNN.

If dispatched by `/meta-research`, read the research prompt from the DB:
`db_read 'research-execute' 'prompt' '{NNN}'`. This provides additional
context and scope instructions.

### Phase 2: Dispatch subagents. Allocate up to 10 Sonnet subagents, one per
   connector. The connector roster:

   | Connector | Tool / Method | Lane |
   |---|---|---|
   | Consensus | `mcp__claude_ai_Consensus__search` | Academic |
   | Scholar Gateway | `mcp__claude_ai_Scholar_Gateway__semanticSearch` | Academic |
   | Synapse.org | `mcp__claude_ai_Synapse_org__search_synapse` | Academic |
   | PubMed | `mcp__claude_ai_PubMed__search_articles` | Academic |
   | Clinical Trials | `mcp__claude_ai_Clinical_Trials__search_trials` | Academic |
   | Context7 | `mcp__claude_ai_Context7__resolve-library-id` + `query-docs` | Code |
   | GitHub | `mcp__github__search_code` / `search_repositories` | Code |
   | Microsoft Learn | `mcp__claude_ai_Microsoft_Learn__microsoft_docs_search` | Code |
   | Hugging Face | `mcp__claude_ai_Hugging_Face__paper_search` / `hub_repo_details` | Both |
   | Web Search | `WebSearch` tool | Both |

   **Skip connectors that have zero mapped topics** in the research plan. Do
   not waste tokens querying connectors with nothing to ask.

   Each subagent receives:
   - The topics assigned to its connector (from the allocation table).
   - The project context summary (first 3 sections of project-context.md).
   - **Explicit instruction to follow the multi-query protocol** (3-5 query
     variations per topic) and include the Source Tally table in output.
   - Instructions to write findings to the artifact DB:
     ```bash
     source artifacts/db.sh
     db_upsert 'research-connector' 'findings' '{NNN}/{connector-name}' "$FINDINGS_CONTENT"
     ```
     where `{connector-name}` is the lowercase connector name (e.g., `consensus`,
     `pubmed`, `github`).

   Use the `research-connector` agent (`subagent_type: "research-connector"`)
   for all research subagents. It has the multi-query protocol, standardized
   output format, source counting, and gap reporting built in. Pass connector
   name, topics, NNN, and project context in the prompt.

4. **Fan out in parallel.** Launch all applicable subagents simultaneously.
   They are independent — no subagent depends on another's output. Wait for
   all to complete.

   For Web Search, allocate up to 3 parallel subagents if there are enough
   topics to justify it. For GitHub, allocate up to 2. All other connectors
   get 1 subagent each.

5. **Collect findings.** After all subagents return, read all connector findings
   from the artifact DB:
   ```bash
   source artifacts/db.sh
   # List all findings for this run:
   sqlite3 artifacts/project.db "SELECT label, content FROM artifacts WHERE skill='research-connector' AND phase='findings' AND label LIKE '{NNN}/%' ORDER BY id ASC;"
   ```

6. **Aggregate source counts.** Parse the `## Source Tally` table from each
   connector findings file. Sum across all connectors:

   ```markdown
   ## Aggregate Source Tally

   | Connector | Queries | Scanned | Cited | Gaps |
   |---|---|---|---|---|
   | Consensus | 12 | 87 | 14 | 0 |
   | GitHub | 15 | 203 | 22 | 1 |
   | ... | ... | ... | ... | ... |
   | **TOTAL** | **N** | **N** | **N** | **N** |
   ```

   Store in the artifact DB:
   ```bash
   source artifacts/db.sh
   db_upsert 'research-execute' 'source-tally' '{NNN}' "$TALLY_CONTENT"
   ```

   **If total scanned < 300**: Log a warning in the tally file noting which
   connectors underperformed. The synthesis should mention this gap. Consider
   whether the topic set was too narrow or if specific connectors need
   different query strategies.

7. **Compile per-topic summaries.** For each topic in the research plan, pull
   findings from all connectors that addressed it and store in DB:
   ```bash
   source artifacts/db.sh
   db_upsert 'research-execute' 'topic' '{NNN}/{slug}' "$TOPIC_CONTENT"
   ```
   Each topic entry should include: the original question, findings by source,
   confidence level (high/medium/low based on source quality and agreement),
   and a recommendation.

8. **Write the synthesis.** Create `artifacts/research/summary/` if it doesn't exist.
   Compile all topic summaries into
   `artifacts/research/summary/{NNN}-{topic-slug}.md` with:
   - Header referencing the research run: `> Research run: {NNN}`
   - **Source counts**: `> Sources: {N} queries | {N} scanned | {N} cited`
   - Executive summary (5-10 bullets — the key takeaways).
   - Per-topic synthesis (condensed from topic files).
   - Confidence map (which findings are well-supported vs. uncertain).
   - Gaps — topics where connectors returned little or nothing.
   - Implications for the project plan.

9. **Triple-counter.** The synthesis is one perspective. Challenge it with
   three model families in parallel:

   **Counter 1 — Sonnet subagent:**
   Spawn a Sonnet subagent with the synthesis. Prompt: "You are a skeptical
   reviewer. Read this research synthesis and identify: unsupported claims,
   missing perspectives, contradictions between sources, and questions the
   research failed to ask." The subagent writes directly to the artifact DB:
   ```bash
   source artifacts/db.sh
   db_upsert 'research-execute' 'counter' '{NNN}/sonnet' "$COUNTER_CONTENT"
   ```

   **Counter 2 — Gemini CLI:** Load `/gemini` for invocation syntax.
   Use the `/gemini` Research / Analysis template with a 120s timeout. Do not
   force `@generalist_agent`.
   Prompt: `"Read this research synthesis and challenge it. Identify weak
   evidence, missing angles, and overclaimed conclusions. Be adversarial.
   $(cat artifacts/research/summary/{NNN}-{topic-slug}.md)"`.
   Output to `/tmp/counter-gemini.md`. Then store in DB:
   ```bash
   source artifacts/db.sh && db_upsert 'research-execute' 'counter' '{NNN}/gemini' "$(cat /tmp/counter-gemini.md)" && rm /tmp/counter-gemini.md
   ```

   **Counter 3 — Codex CLI:** Load `/codex` for invocation syntax.
   Key params: `--sandbox read-only`, `--ephemeral`, 180s timeout.
   Prompt: write a temp prompt file that contains the instructions below plus
   `artifacts/research/summary/{NNN}-{topic-slug}.md`, then pass it to Codex
   via stdin (`- < /tmp/counter-codex-prompt.md`):
   `"Review this research synthesis for technical accuracy. Flag any claims
   about libraries, frameworks, or APIs that are outdated or incorrect."`
   Output to `/tmp/counter-codex.md`. Then store in DB:
   ```bash
   source artifacts/db.sh && db_upsert 'research-execute' 'counter' '{NNN}/codex' "$(cat /tmp/counter-codex.md)" && rm /tmp/counter-codex.md
   ```

   Launch all three in parallel. If Gemini fails (unavailable, timeout, or
   empty output), retry with Copilot as a fallback — load `/copilot` for
   invocation syntax. Same prompt, 120s timeout. Output to
   `/tmp/counter-copilot.md`. Then store in DB:
   ```bash
   source artifacts/db.sh && db_upsert 'research-execute' 'counter' '{NNN}/copilot' "$(cat /tmp/counter-copilot.md)" && rm /tmp/counter-copilot.md
   ```
   Store Copilot counters under label `copilot` — they count equivalently to
   Gemini for synthesis purposes. If both Gemini and Copilot fail, note it
   and proceed. At minimum, the Sonnet counter always runs.

10. **Integrate counter feedback.** Read all counters from the artifact DB:
    ```bash
    source artifacts/db.sh
    COUNTER_SONNET=$(db_read 'research-execute' 'counter' '{NNN}/sonnet')
    COUNTER_GEMINI=$(db_read 'research-execute' 'counter' '{NNN}/gemini')
    COUNTER_CODEX=$(db_read 'research-execute' 'counter' '{NNN}/codex')
    ```
    If any counter
    raised a valid concern, update the synthesis — add a "Challenges and
    Caveats" section that addresses each point. Do not silently dismiss
    counter-arguments.

11. **Present results.** Give the user the executive summary from the
    synthesis, the **aggregate source counts**, and ask if they want to dive
    into any specific topic. Flag the gaps and low-confidence areas.

12. **Homelab Tools memory sync (MANDATORY).** Store the research summary
    in Qdrant so home Claude can reference findings across projects. Per
    cross-cutting rule 7:
    - Use `mcp__claude_ai_Homelab_Tools__memory_call` with `tool: 'store_memory'`.
    - Content: executive summary + source tally + key findings (condensed).
    - Tags: `research`, `{NNN}`, `{project-name}`.
    - Search first to avoid duplicating a recent entry for the same NNN.

## Exit condition

All connector subagents have returned findings (stored in DB under
`research-connector` / `findings` / `{NNN}/*`). Per-topic entries exist in DB
(`research-execute` / `topic` / `{NNN}/*`).
`artifacts/research/summary/{NNN}-{topic-slug}.md` is written with source counts
in the header. `source-tally` exists in DB. At least one counter has run and
feedback is integrated. The user has seen the summary.

## Output artifacts

**Artifact DB (intermediate):**
```
research-plan      / plan          / {NNN}           — research plan (from research-plan)
research-execute   / prompt        / {NNN}           — meta-research dispatch prompt (optional)
research-connector / findings      / {NNN}/{connector} — raw findings per connector
research-execute   / source-tally  / {NNN}           — aggregate source counts
research-execute   / topic         / {NNN}/{slug}    — per-topic summaries
research-execute   / counter       / {NNN}/sonnet    — Sonnet counter
research-execute   / counter       / {NNN}/gemini    — Gemini counter
research-execute   / counter       / {NNN}/codex     — Codex counter
```

**File (final output — do not change):**
```
artifacts/research/summary/{NNN}-{topic-slug}.md    — final synthesis
```

## Examples

```
User: "Run the research"
Action: Read research plan from artifact DB. Dispatch subagents to
        all mapped connectors in parallel (multi-query protocol). Collect
        findings. Aggregate source counts. Compile topic summaries and
        synthesis. Run triple-counter. Integrate feedback. Present executive
        summary with source tally.
```

```
User: "Execute research but skip the academic connectors"
Action: Filter the plan to code-lane and both-lane connectors only. Dispatch
        accordingly. Note the skipped connectors in the synthesis.
```

```
User: "Re-run research for topic 3 only"
Action: Create a new run directory. Dispatch only the connectors mapped to
        topic 3. Update the topic file and synthesis with new findings.
```

## Cross-cutting

Before completing, read and follow `../references/cross-cutting-rules.md`.
