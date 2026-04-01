---
name: meta-deep-research
description: "Multi-model deep research with adversarial debate. Dispatches Opus to orchestrate ~20 workers across 3 model families. Triggers on deep research, exhaustive research, leave no stone unturned."
---

# meta-deep-research

Chat-facing dispatcher. Asks clarifying questions, builds a concise research
prompt file, creates the research folder, dispatches a single Opus subagent to
handle the entire research protocol, then presents the summary when done.

The main chat context stays lean — all heavy work happens in the subagent.

## Chain

```
Clarify → Write prompt → Create folder → Dispatch Opus → Present summary
```

## Instructions

### Step 1: Clarify the Research Question

Ask the user targeted questions to maximize the quality of the research prompt.
Do not proceed until you have clear answers:

**Required:**
- What exactly do you need to know? (restate the question back precisely)
- What decision will this research inform?
- How broad should the research go? (narrow/focused vs. exhaustive/comprehensive)

**If relevant:**
- Any known constraints, biases, or assumptions to challenge?
- Time sensitivity — recent sources only or historical context too?
- Specific technologies, frameworks, or domains to cover?
- Any prior research to build on? (check `artifacts/research/` folder)

Keep the interview to 3-5 questions. Don't over-interview.

### Step 2: Read Project Context

If `project-context.md` exists in the project root, read it. Extract the
sections relevant to the research question — compress to essentials only.

### Step 3: Determine Folder Number

Check the `artifacts/research/` directory for existing numbered folders. Both regular
research (`001`, `002`) and deep research (`001D`, `002D`) share one sequence.

Examples:
- No folders exist → `001D`
- `001` exists → `002D`
- `001`, `002D` exist → `003D`
- `001`, `002D`, `003` exist → `004D`

Extract the highest number, increment by 1, append `D`.

### Step 4: Create Folder Structure

```
artifacts/research/
  summary/              ← create if doesn't exist
  {NNN}D/               ← this run's working folder
```

### Step 5: Write the Research Prompt

Write `artifacts/research/{NNN}D/deep_research_prompt.md` — **max 200 lines**.

This file is the ONLY input the Opus subagent reads to understand the full
scope. Maximize conciseness without context loss.

**Schema:**

```markdown
# Deep Research Prompt — {NNN}D

## Research Question
[The precise, refined question from the clarifying discussion]

## Sub-Questions
[5-10 specific sub-questions identified during clarification, numbered]

## Scope
- Breadth: [narrow | focused | broad | exhaustive]
- Time horizon: [recent only (2025-2026) | include historical]
- Domain constraints: [any specific domains to include/exclude]

## Project Context
[Compressed relevant sections from project-context.md — skip if no project]

## Known Prior Research
[Reference existing research folders if any, or "none"]

## Output Configuration
- Research folder: artifacts/research/{NNN}D/
- Summary destination: artifacts/research/summary/{NNN}D-{topic-slug}.md
- Topic slug: {3-4-word-kebab-case}

## Special Instructions
[Any user-specified constraints, biases to challenge, or focus areas]
```

### Step 6: Dispatch Opus Subagent

Spawn exactly ONE Opus subagent. The prompt should be concise — the subagent
reads the full protocol from the execute skill file.

**Subagent prompt template:**

```
You are the deep research orchestrator. Execute the full multi-model deep
research protocol.

1. Read the skill instructions at:
   [absolute path to skills/meta-deep-research-execute/SKILL.md]

2. Read your research prompt at:
   artifacts/research/{NNN}D/deep_research_prompt.md

3. Follow the skill instructions completely. All intermediate files go in
   artifacts/research/{NNN}D/ using 3-4 word kebab-case filenames.

4. Write the final summary to:
   artifacts/research/summary/{NNN}D-{topic-slug}.md

5. When complete, report back with ONLY:
   - The summary file path
   - Source tally: {N} queries | {N} scanned | {N} cited
   - Total claims: verified / contested / debunked counts
   - Whether coverage expansion (Phase 2.5) added emergent topics
   - Any CONTESTED findings that need human judgment (one-line each)
```

Do NOT pass the full research protocol in the prompt — the subagent reads it
from the SKILL.md file. This keeps the dispatch lightweight.

### Step 7: Present Results

When the Opus subagent completes:

1. Read `artifacts/research/summary/{NNN}D-{topic-slug}.md`
2. Read `artifacts/research/{NNN}D/source-tally.md`
3. Present the executive summary, confidence map, and **source counts** to the user
4. Highlight any CONTESTED findings that need human judgment
5. Note any DEBUNKED claims (hallucinations caught by debate)
6. If the coverage expansion added emergent topics, call them out specifically

Then offer next steps:

> "Deep research complete. **{N} sources scanned | {N} cited** across {N}
> connectors. {N} verified, {N} contested, {N} debunked.
> Coverage expansion added {N} emergent topics.
>
> 1. **Dive deeper** — re-run debate on contested findings
> 2. **Narrow focus** — deep-dive a specific sub-question
> 3. **Apply findings** — use this to inform `/build-plan` or `/meta-evolve`
> 4. **Done** — research is complete"

## Error Handling

- If the Opus subagent fails or times out, read whatever intermediate files
  exist in `artifacts/research/{NNN}D/` and present partial findings.
- If `project-context.md` doesn't exist, proceed without it — research can
  still run on the user's question alone.
- If `artifacts/research/` folder doesn't exist, create it.

## Examples

```
User: "Deep research whether we should use PostgreSQL or DynamoDB"
Action: Ask about scale, team experience, data model, what decision this
        informs. Write prompt. Create artifacts/research/001D/. Dispatch Opus.
        Present summary when done.
```

```
User: "/meta-deep-research — is RAG or fine-tuning better for our KB?"
Action: Ask about data volume, update frequency, accuracy requirements,
        latency budget. Write prompt. Dispatch. Present.
```

```
User: "Leave no stone unturned on HIPAA compliance for our SaaS"
Action: Set scope to exhaustive. Ask about specific HIPAA areas of concern.
        Write prompt with compliance-specific sub-questions. Dispatch.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
