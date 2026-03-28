# Protocol Detail

## Phase 0: Setup

1. Read `deep_research_prompt.md`.
2. Run DB setup (see SKILL.md).
3. Verify: `source artifacts/db.sh && db_init && echo "DB OK"`
4. Write `artifacts/research/{NNN}D/progress.md`:
```
- [x] Phase 0: Setup
- [ ] Phase 1: Decomposition
- [ ] Phase 2: Research fan-out
- [ ] Phase 2.5: Coverage expansion
- [ ] Phase 3: Steelman debate
- [ ] Phase 4: Convergence scoring
- [ ] Phase 5: Summary
- [ ] Phase 6: Report
```

## Phase 1: Decomposition

**Checkpoint:** `db_exists 'claude-deep-research-execute' 'dispatch-table' '{NNN}D'` → skip to Phase 2.

1. Validate sub-questions. Add missing, remove duplicates.
2. Classify:

| Evidence Type | Track |
|---|---|
| Academic | B (Consensus, Scholar Gateway, PubMed) |
| Technical | B (Context7, GitHub) + C (WebSearch) |
| Market/Practical | C (WebSearch) |
| Reasoning | A (Opus) |

3. Assign each sub-question to 2+ tracks.
4. Calculate source target: `sub_questions × connectors × 3 × 20`.
5. `db_upsert 'claude-deep-research-execute' 'dispatch-table' '{NNN}D' "$TABLE"`
6. Update progress.md.

## Phase 2: Fan-Out

**Checkpoint:** If findings exist for this NNN in DB, skip completed tracks.

Launch all 3 tracks simultaneously via Agent tool.

### Track A: Opus Reasoning (2-3 subagents, model: "opus")

Per subagent prompt:
```
Research these sub-questions using extended thinking. Full MCP connector access.
Cite every claim. Flag uncertainty.

Sub-questions: [LIST]
Project context: [FROM PROMPT FILE]

Output format per sub-question:
## [Sub-question]
### Finding — [answer with citations]
### Confidence — HIGH/MEDIUM/LOW with justification
### Gaps — what you could NOT verify

## Source Tally
| Queries executed | Results scanned | Sources cited |
|---|---|---|
| [N] | [N] | [N] |
```

### Track B: Connector Sweep (5-10 subagents, model: "sonnet")

One per MCP connector with mapped topics. Skip connectors with zero topics.

| Connector | Tool |
|---|---|
| Consensus | `mcp__claude_ai_Consensus__search` |
| Scholar Gateway | `mcp__claude_ai_Scholar_Gateway__semanticSearch` |
| PubMed | `mcp__claude_ai_PubMed__search_articles` |
| Context7 | `mcp__claude_ai_Context7__resolve-library-id` + `query-docs` |
| GitHub | `mcp__gateway__github_call` |
| Microsoft Learn | `mcp__claude_ai_Microsoft_Learn__microsoft_docs_search` |
| Hugging Face | `mcp__claude_ai_Hugging_Face__paper_search` |
| Web Search | `WebSearch` |

Per subagent prompt:
```
You are a research connector agent. Query [CONNECTOR] for these topics using
3-5 query variations per topic (direct, synonym, narrower, broader, negative).
De-duplicate across variations.

Topics: [LIST]
Project context: [BRIEF]

Return findings in your response. Do NOT write to any database.

Output format per topic:
## Topic: [name]
### Queries Executed
1. `[query]` — [N] results
2. `[query]` — [N] results
3. `[query]` — [N] results

### Findings
- **Source**: [citation] | **Takeaway**: [insight] | **Confidence**: high/medium/low

### Gaps
[What the connector could NOT answer]

## Source Tally
| Queries executed | Results scanned | Sources cited |
|---|---|---|
| [N] | [N] | [N] |
```

### Track C: WebSearch Research (3-4 subagents, model: "sonnet")

**Workers 1-2** — primary technical research, 1-3 sub-questions each:
```
Use WebSearch to research with technical precision. Find recent (2025-2026)
sources, official docs, benchmarks, practitioner posts.

Sub-questions: [LIST]

Per sub-question: findings with citations, confidence, what you could NOT verify.
Include Source Tally.
```

**Worker 3** — devil's advocate:
```
Use WebSearch to find evidence AGAINST conventional wisdom for these questions.
Find: known bugs, failure cases, better alternatives, outdated info still cited,
migration-away stories.

Sub-questions: [LIST]
Expected mainstream answers: [LIST]

Per sub-question: counter-evidence, alternative approaches, risks.
Include Source Tally.
```

**Worker 4** (only if scope is "broad" or "exhaustive") — web grounding:
```
Use WebSearch for broad grounding: case studies, production deployments,
engineering blogs. Per finding: company, scale, outcome, would-they-do-it-again.
Include Source Tally.
```

### After All Tracks Complete

1. Batch-write each response:
   `db_upsert 'research-connector' 'findings' '{NNN}D/{descriptive-name}' "$CONTENT"`
2. Aggregate source tallies:
   `db_upsert 'claude-deep-research-execute' 'source-tally' '{NNN}D' "$TALLY"`
3. Update progress.md.

## Phase 2.5: Coverage Expansion

**Checkpoint:** `db_exists 'claude-deep-research-execute' 'addendum' '{NNN}D'` → skip to Phase 3.

### Step 1: Two Reviewers (parallel, Agent tool)

**Reviewer A** (model: "opus"):
```
You are a research coverage auditor. Read:
1. Research prompt: [CONTENT]
2. Dispatch table: [CONTENT]
3. All findings: [COMPRESSED KEY FINDINGS]
4. Source tally: [CONTENT]

Identify:
- Sub-questions with thin evidence (low source count, single-source, low confidence)
- Emergent topics that surfaced but weren't in original prompt
- Well-known approaches the research missed
- Source count vs target: [ACTUAL] vs [TARGET]

Output: numbered list of gaps with severity (critical/moderate/minor).
```

**Reviewer B** (model: "sonnet", with WebSearch):
```
Same mandate as Reviewer A, but use WebSearch to actively hunt for what's missing.
Search for: "[topic] alternatives 2026", recent developments, practitioner criticism.

Output: numbered list of gaps with URLs for evidence found.
```

Write both to DB:
```bash
db_upsert 'claude-deep-research-execute' 'coverage-review' '{NNN}D/reviewer-a' "$CONTENT"
db_upsert 'claude-deep-research-execute' 'coverage-review' '{NNN}D/reviewer-b' "$CONTENT"
```

### Step 2: Addendum Decision

Run addendum if ANY:
- Reviewers found >2 thin areas
- Source count < adaptive target
- >1 emergent topic identified

Skip if none met. Note decision in methodology.

### Step 3: Addendum Execution (if triggered)

Synthesize reviews → dispatch additional workers using Phase 2 patterns →
label outputs with `-addendum` suffix → re-aggregate source tally.
Max 1 cycle. Update progress.md.

## Phase 3: Steelman Debate

**Checkpoint:** `db_exists 'claude-deep-research-execute' 'debate' '{NNN}D/judgment'` → skip to Phase 4.

Read ALL findings from DB. Compress to findings brief: key claims, evidence,
confidence per sub-question.

### Advocate (model: "sonnet")

```
Build the strongest case FOR the emerging research consensus.

Findings brief:
[COMPRESSED FINDINGS]

Per sub-question:
1. Consensus position — state clearly
2. Strongest supporting evidence — cite sources
3. Genuine weaknesses — acknowledge honestly
4. Confidence — HIGH/MEDIUM/LOW with justification
```

### Challenger (model: "sonnet")

```
Build the strongest case AGAINST the emerging consensus. You have WebSearch —
use it to find fresh counter-evidence.

Findings brief:
[SAME COMPRESSED FINDINGS]

Per sub-question:
1. What the consensus claims
2. Strongest counter-evidence — search for it
3. Failure cases, criticisms, better alternatives
4. Counter-case strength — STRONG/MODERATE/WEAK

Find REAL counter-evidence. If consensus is genuinely strong on a point, say so.
```

Write both to DB:
```bash
db_upsert 'claude-deep-research-execute' 'debate' '{NNN}D/advocate' "$CONTENT"
db_upsert 'claude-deep-research-execute' 'debate' '{NNN}D/challenger' "$CONTENT"
```

### Judgment (you, the orchestrator)

Read both positions. Use extended thinking. Score every claim per convergence
matrix (SKILL.md). Weight: academic > docs > blogs > forums > inference.
Recent (2025-2026) weighted higher. First-hand experience over theory.

```bash
db_upsert 'claude-deep-research-execute' 'debate' '{NNN}D/judgment' "$CONTENT"
```

Update progress.md.

## Phase 4: Convergence Scoring

```bash
db_upsert 'claude-deep-research-execute' 'convergence-scoring' '{NNN}D' "$SCORES"
```

## Phase 5: Summary

Write `artifacts/research/summary/{NNN}D-{topic-slug}.md`. Create `summary/` if needed.

Structure:
```markdown
# Deep Research: {Topic}

> Folder: research/{NNN}D/ | Date: {DATE}
> Method: Claude-only, steelman/steelman debate
> Models: Opus 4.6 (orchestrator + reasoning), Sonnet 4.6 ({N} subagents)
> Connectors: {LIST}
> Debate: Advocate vs Challenger, orchestrator judgment
> Addendum: [ran — {reason} | skipped — sufficient coverage]
> Sources: {N} queries | {N} scanned | {N} cited (target: {N})
> Claims: {N} verified, {N} high, {N} contested, {N} uncertain, {N} debunked

## Executive Summary
[10-15 bullets. Each: claim, confidence, evidence basis.]

## Confidence Map
| # | Sub-Question | Confidence | Finding |
|---|---|---|---|

## Detailed Findings
### SQ-1: [question]
**Confidence**: [level] | **Finding**: [answer]
**Evidence**: [citations] | **Debate**: Advocate: [pos] / Challenger: [pos] / Judgment: [outcome]

## Addendum Findings
[If ran: what emerged, impact]

## Contested Findings
[Both sides for claims with strong evidence on each side]

## Open Questions
[UNCERTAIN claims + suggested follow-up]

## Debunked Claims
[Claims that didn't survive challenge]

## Source Index
[By type: Academic | Docs | Web | Code — with tally per track]

## Methodology
[Worker count, debate structure, addendum decision, source counting]
```

Update progress.md.

## Phase 6: Report

1. Store to Qdrant:
```
mcp__gateway__memory_call > store
content: executive summary + tally + claims (~500 words)
tags: research, deep-research, claude-deep-research, {NNN}D, {project}
category: {project or "general"}
```

2. Mark progress.md complete.
3. Return to dispatcher: summary path, source tally, claim counts, contested findings.
