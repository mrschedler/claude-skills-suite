---
name: meta-deep-research-execute
description: "Internal Opus subagent for deep research. Runs ~20 workers across 3 model families with adversarial debate. Never invoke directly — dispatched by /meta-deep-research."
---

# meta-deep-research-execute

Full multi-model deep research protocol. This skill is executed by an Opus
subagent dispatched from `/meta-deep-research`. It reads its input from
`deep_research_prompt.md` in the research folder, orchestrates all workers,
and writes the final summary.

**Do not invoke this skill directly.** It is triggered by `/meta-deep-research`.

**For detailed phase instructions, read `references/protocol-detail.md`.**

## Source Counting Target

**Deep research target: 1000+ sources scanned.**

Every connector subagent and external CLI worker must track sources. The
orchestrator aggregates counts after Phase 2 and again after any addendum
cycles. The final summary header reports the total.

## Inputs

The dispatching skill provides:
- The NNN identifier for this deep research run (e.g., `003D`)
- Path to `deep_research_prompt.md` (in `artifacts/research/` or passed directly)

Read the prompt file first. It contains: the research question, sub-questions,
scope, project context, and output configuration.

## File Naming Convention

All intermediate files use 3-4 word kebab-case names that describe the content:
- `websocket-scaling-limits.md` (not `codex-worker-1.md`)
- `rag-accuracy-benchmarks.md` (not `sonnet-connector-3.md`)
- `dynamo-failure-stories.md` (not `gemini-contradictions.md`)

The filename should tell you what's inside without opening it.

## Phase Overview

### Phase 1: Decomposition

Validate and refine the sub-questions from the dispatcher. Classify each by
evidence type (Academic, Technical, Market, Reasoning). Assign each sub-question
to 2-3 model families ensuring cross-coverage. Write the dispatch table to the
artifact DB:
```bash
source artifacts/db.sh
db_upsert 'meta-deep-research-execute' 'dispatch-table' '{NNN}D' "$CONTENT"
```

### Phase 2: Parallel Research Fan-Out

Launch all 4 tracks simultaneously:

- **Track A — Opus Deep Reasoning** (2-3 subagents): Extended thinking on
  "Reasoning" sub-questions. Full MCP connector access. Cite every claim.
- **Track B — Sonnet Connector Sweep** (7-10 subagents): One per MCP connector
  (Consensus, Scholar Gateway, PubMed, Synapse, Clinical Trials, Context7,
  GitHub, MS Learn, HuggingFace, WebSearch). Uses `research-connector` agent
  with multi-query protocol (3-5 queries per topic). Each subagent writes to:
  `research-connector` / `findings` / `{NNN}D/{descriptive-name}` in the DB.
- **Track C — Codex Technical Validation** (up to 4 workers): Workers 1-3 do
  primary technical research. Worker 4 runs devil's advocate (find evidence
  AGAINST conventional wisdom). Slot 5 reserved for Phase 2.5/3.
- **Track D — Gemini Web Grounding** (2 instances): Instance 1 does broad
  Google Search research + case studies. Instance 2 hunts contradictions.
  Phase 2.5/3 Gemini runs AFTER Track D completes (sequential).

All workers include a Source Tally in their output. After completion, aggregate
all tallies and store:
```bash
source artifacts/db.sh
db_upsert 'meta-deep-research-execute' 'source-tally' '{NNN}D' "$TALLY_CONTENT"
```

### Phase 2.5: Coverage Expansion (MANDATORY)

This phase ALWAYS runs. It is not optional or conditional. Initial research
inevitably surfaces topics and alternatives not in the original prompt.

**Step 1 — Coverage Debate:** Opus + Codex reviewers run in parallel. Gemini
reviewer runs AFTER Track D completes (respects 2-session limit). Each reads
the original prompt, dispatch table, all findings, and the source tally. They
identify:
- Thin evidence areas needing reinforcement
- Emergent topics that surfaced during research
- Missing well-known approaches/tools
- Underperforming connectors
- Source count gaps vs. 1000+ target

Output stored in artifact DB:
- `meta-deep-research-execute` / `coverage-review` / `{NNN}D/claude`
- `meta-deep-research-execute` / `coverage-review` / `{NNN}D/gemini`
- `meta-deep-research-execute` / `coverage-review` / `{NNN}D/codex`

**Step 2 — Addendum Creation:** A fresh Opus subagent (not a prior participant)
synthesizes the three reviews into an addendum stored at
`meta-deep-research-execute` / `addendum` / `{NNN}D` in the DB. Content: reinforcement
targets, new sub-questions from emergent topics, missed alternatives, source
count plan, and worker allocation.

**Step 3 — Addendum Research Cycle:** Execute the addendum using Phase 2
patterns. Update dispatch table with `[ADDENDUM]` tags. Name output files
with `-addendum` suffix. Re-aggregate source tallies. **Max 1 addendum cycle**
to prevent infinite loops.

### Phase 3: Cross-Model Debate (3 Rounds)

All debate outputs go to the artifact DB under
`meta-deep-research-execute` / `debate` / `{NNN}D/{file-stem}`.
The debate covers ALL findings (original + addendum).

- **Round 1 — Present:** Each model family (Claude/Codex/Gemini) compiles its
  findings into a position paper. Per sub-question: claim, evidence, confidence,
  gaps. DB label: `{NNN}D/position-{model}`
- **Round 2 — Challenge:** Each model reads the OTHER two positions and attacks
  them (insufficient evidence, wrong details, contradictions, hallucinations).
  DB label: `{NNN}D/challenge-{model}`
- **Round 3 — Respond + Converge:** Each model responds to challenges with
  CONCEDE / REBUT / ESCALATE per claim. DB label: `{NNN}D/response-{model}`

### Phase 4: Convergence Scoring

Read all 9 debate files. Score every major claim using extended thinking.

| Outcome | Confidence | Action |
|---|---|---|
| 3/3 agree | **VERIFIED** | Report as fact |
| 2/3 agree, 1 conceded | **HIGH** | Report with concession note |
| 2/3 agree, 1 rebutted | **CONTESTED** | Report both sides |
| All 3 differ | **UNCERTAIN** | Open Questions section |
| No model could rebut challenge | **DEBUNKED** | Debate trail only |
| All 3 escalated | **UNRESOLVED** | Gaps section + follow-up |

Source quality weighting: academic papers > official docs > engineering blogs
> forums > LLM inference. Recent sources (2025-2026) weighted higher. First-hand
experience weighted higher than theory.

Store results in the artifact DB:
```bash
source artifacts/db.sh
db_upsert 'meta-deep-research-execute' 'convergence-scoring' '{NNN}D' "$SCORING_CONTENT"
```

### Phase 5: Write Summary

Write to `artifacts/research/summary/{NNN}D-{topic-slug}.md` (300-500 lines). This
is a final output file — create `artifacts/research/summary/` if it doesn't exist.
Intermediate artifacts (dispatch table, findings, coverage reviews, addendum, debate,
convergence scoring) are all in the artifact DB. Structure:

- Header block (models, connectors, source counts, claim counts)
- Executive Summary (10-15 highest-confidence bullets)
- Confidence Map (table of all sub-questions with confidence + agreement)
- Detailed Findings (per sub-question: confidence, agreement, finding, evidence, debate trail)
- Addendum Findings (emergent topics and their impact)
- Contested Findings (both sides presented)
- Open Questions (UNCERTAIN/UNRESOLVED with follow-up suggestions)
- Debunked Claims (hallucinations caught by debate)
- Source Index (academic, docs, web, code — with tally by track)
- Methodology (worker allocation, debate structure, addendum rationale)

### Phase 6: Report Completion

Report back to the dispatcher with ONLY:
- Summary file path
- Source tally: {N} queries | {N} scanned | {N} cited
- Claim counts: verified / high / contested / debunked
- Whether addendum cycle ran (and what it added)
- Any CONTESTED findings needing human judgment (one line each)

**Homelab Tools memory sync (MANDATORY):** Before returning, store the
deep research summary in Qdrant. Per cross-cutting rule 7:
- Use `mcp__claude_ai_Homelab_Tools__memory_call` with `tool: 'store_memory'`.
- Content: executive summary + source tally + claim counts + contested
  findings (condensed to ~500 words).
- Tags: `research`, `deep-research`, `{NNN}D`, `{project-name}`.
- Search first to avoid duplicating a recent entry for the same NNN.

## Error Handling

- **Gemini unavailable**: Try Copilot as fallback for Track D (same 2-slot
  limit, same prompt patterns). If both fail, use WebSearch. Debate becomes 2-model.
- **Codex unavailable**: Redistribute to Sonnet. Debate becomes 2-model.
- **Both Gemini+Copilot unavailable**: WebSearch for Track D. Debate becomes 2-model.
- **All CLIs unavailable**: Claude only + self-consistency (3 Sonnet subagents).
  Note "single-model" in methodology.
- **Subagent/debate failure**: Note gap, mark affected claims UNCERTAIN.
  Proceed with available responses.
- **Coverage review failure**: Proceed with available reviews. If ALL fail,
  write minimal addendum targeting source count gaps only.
- **Addendum cycle**: Exactly 1 cycle, mandatory. Remaining gaps noted in
  summary, no looping.

## Cost Awareness

~17 workers + mandatory coverage expansion + addendum workers + 3 debate rounds.
Up to 5 Opus subagents, 8-10+ Sonnet subagents, 4 Codex workers (max 5 concurrent),
2 Gemini instances (max 2 concurrent), plus 9 debate exchanges. Gemini and Codex
phases run sequentially when needed to respect hard concurrency limits. Reserve
for decisions where being wrong costs more than the research.

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
