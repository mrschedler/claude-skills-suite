# Deep Research Protocol — Detailed Phase Instructions

This file contains the full step-by-step instructions for each phase of the
deep research protocol. The orchestrating subagent reads this file when
executing the research.

## Phase 1: Decomposition

Read `deep_research_prompt.md`. The dispatcher already identified sub-questions
during the clarifying interview. Your job:

1. **Validate and refine the sub-questions.** Add any the dispatcher missed.
   Remove duplicates. Ensure each is:
   - Specific enough for a single worker
   - Independent enough for parallel research
   - Answerable with evidence (not opinion)

2. **Classify each by evidence type:**

   | Type | Primary Workers |
   |---|---|
   | Academic | Sonnet (MCP connectors) |
   | Technical | Codex + Sonnet (Context7, GitHub) |
   | Market | Gemini (Google Search) |
   | Reasoning | Opus subagent (extended thinking) |

3. **Build the dispatch table.** Assign each sub-question to 2-3 model
   families. Every sub-question MUST be covered by at least 2 families.

4. **Write the dispatch table** to the artifact DB:
   ```bash
   source artifacts/db.sh
   db_upsert 'meta-deep-research-execute' 'dispatch-table' '{NNN}D' "$DISPATCH_TABLE_CONTENT"
   ```

## Phase 2: Parallel Research Fan-Out

Launch all 4 tracks simultaneously.

### Track A: Opus Deep Reasoning (2-3 subagents)

Spawn Opus subagents for "Reasoning" sub-questions. Each receives:
- Its assigned sub-questions
- Project context from the prompt file
- Full MCP connector access
- Instruction: "Use extended thinking. Cite every claim. Flag uncertainty."
- Instruction: "Track sources — include a Source Tally at the end of your output."

Output: `research-connector` / `findings` / `{NNN}D/{descriptive-name}` in the
artifact DB. Track A Opus subagents write their output there directly.

### Track B: Sonnet Connector Sweep (7-10 subagents)

One Sonnet subagent per MCP connector with mapped topics. Use the
`research-connector` agent — it has the multi-query protocol (3-5 queries per
topic) and source counting built in.

| Connector | Tool |
|---|---|
| Consensus | `mcp__claude_ai_Consensus__search` |
| Scholar Gateway | `mcp__claude_ai_Scholar_Gateway__semanticSearch` |
| PubMed | `mcp__claude_ai_PubMed__search_articles` |
| Synapse.org | `mcp__claude_ai_Synapse_org__search_synapse` |
| Clinical Trials | `mcp__claude_ai_Clinical_Trials__search_trials` |
| Context7 | `mcp__claude_ai_Context7__resolve-library-id` + `query-docs` |
| GitHub | `mcp__github__search_code` / `search_repositories` |
| Microsoft Learn | `mcp__claude_ai_Microsoft_Learn__microsoft_docs_search` |
| Hugging Face | `mcp__claude_ai_Hugging_Face__paper_search` |
| Web Search | `WebSearch` |

Skip connectors with zero mapped sub-questions.

**Each subagent MUST follow the multi-query protocol** and include the Source
Tally table in its output.

Output: `research-connector` / `findings` / `{NNN}D/{descriptive-name}` in the
artifact DB per connector (written by the research-connector agent).

### Track C: Codex Technical Validation (up to 4 workers)

**Hard limit: 4 concurrent Codex sessions.** Reserve 1 slot for Phase 2.5/3.

```bash
CODEX=$(command -v codex 2>/dev/null)
test -x "$CODEX" || CODEX="/opt/homebrew/bin/codex"
if [ ! -x "$CODEX" ] && [ -d "$HOME/.nvm/versions/node" ]; then
  CODEX=$(find "$HOME/.nvm/versions/node" -path '*/bin/codex' -type f 2>/dev/null | sort -V | tail -1)
fi
export PATH="$(dirname "$CODEX"):$PATH"
GTIMEOUT="/opt/homebrew/bin/gtimeout"; test -x "$GTIMEOUT" || GTIMEOUT="/opt/homebrew/bin/timeout"
test -x "$CODEX" || { echo "Codex unavailable — reassigning to Sonnet"; }
```

**Workers 1-3: Primary research** — each gets 1-2 technical sub-questions.

```bash
$GTIMEOUT 180 "$CODEX" exec --ephemeral --sandbox read-only --skip-git-repo-check \
  --cd /path/to/project \
  "Research the following with technical precision. Check actual library
   docs, API signatures, and known issues. Do NOT speculate — say so if
   unsure. Cite sources. At the end, include:
   ## Source Tally
   - Queries executed: [N]
   - Results scanned: [N]
   - Sources cited: [N]

   Question: [SUB-QUESTION]
   Context: [relevant excerpt]

   Format:
   ## Findings
   [evidence-backed answers with citations]
   ## Confidence
   [HIGH/MEDIUM/LOW with justification]
   ## What I Could NOT Verify
   [gaps — be honest]" \
  2>/dev/null > /tmp/codex-worker-{N}.md
source artifacts/db.sh && db_upsert 'research-connector' 'findings' '{NNN}D/{descriptive-name}' "$(cat /tmp/codex-worker-{N}.md)" && rm /tmp/codex-worker-{N}.md
echo $! >> /tmp/codex-slots.pid
```

**Worker 4: Devil's advocate** — find problems with the likely answers.
Covers all sub-questions assigned to Codex devil's advocate in the dispatch
table. Broader scope than primary workers to compensate for single worker.

```bash
$GTIMEOUT 180 "$CODEX" exec --ephemeral --sandbox read-only --skip-git-repo-check \
  --cd /path/to/project \
  "You are a devil's advocate. Find evidence AGAINST the conventional
   wisdom. Look for: known bugs, failure cases, better alternatives,
   outdated info people still cite. Include Source Tally at end.

   Questions: [ALL DEVIL'S ADVOCATE SUB-QUESTIONS]
   Conventional answers: [what most would say per question]

   Format per question:
   ## Counter-Evidence
   ## Alternative Approaches
   ## Risks of Conventional Approach
   ## Source Tally
   - Queries executed: [N]
   - Results scanned: [N]
   - Sources cited: [N]" \
  2>/dev/null > /tmp/codex-devil.md
source artifacts/db.sh && db_upsert 'research-connector' 'findings' '{NNN}D/{descriptive-name}-counter' "$(cat /tmp/codex-devil.md)" && rm /tmp/codex-devil.md
echo $! >> /tmp/codex-slots.pid
```

### Track D: Gemini Web Grounding (2 instances)

**Hard limit: 2 concurrent Gemini sessions.** All Gemini phases are sequential
with Track D — never overlap with Phase 2.5 or Phase 3 Gemini calls.

```bash
GEMINI="/Users/trevorbyrum/.npm-global/bin/gemini"
test -x "$GEMINI" || GEMINI="/opt/homebrew/bin/gemini"
test -x "$GEMINI" || { echo "Gemini unavailable — using WebSearch fallback"; }
```

**Gemini 1: Primary research + case studies** — broad, Google Search grounded.
Combines primary research and real-world case study collection into one worker.

```bash
unset DEBUG 2>/dev/null
timeout 180 "$GEMINI" --agent generalist -p \
  "Research thoroughly using web search. Find recent (2025-2026) sources,
   practitioner posts, conference talks, case studies. Prioritize
   first-hand experience over theory.

   Questions: [LIST]

   Per question provide:
   - Answer with citations (URLs)
   - Source quality (authoritative vs blog vs forum)
   - Recency
   - Consensus level (agreed vs contested)

   ALSO find real-world case studies and production deployments for each
   question where applicable. Per case: company, scale, outcome, timeline,
   would-they-do-it-again. Prioritize engineering blogs over generic how-tos.

   At the END, include:
   ## Source Tally
   - Web searches executed: [N]
   - Results scanned: [N]
   - Sources cited: [N]" \
  2>/dev/null > /tmp/gemini-primary.md
source artifacts/db.sh && db_upsert 'research-connector' 'findings' '{NNN}D/{descriptive-name}' "$(cat /tmp/gemini-primary.md)" && rm /tmp/gemini-primary.md
```

**Gemini 2: Contradiction hunter** — explicitly adversarial.

```bash
unset DEBUG 2>/dev/null
timeout 180 "$GEMINI" --agent generalist -p \
  "Find CONTRADICTING evidence and dissenting opinions on:
   [LIST WITH EXPECTED MAINSTREAM ANSWERS]

   Find: posts arguing AGAINST the popular answer, failure stories,
   unexpected benchmarks, migration-away stories.

   Include Source Tally at end (searches executed, results scanned, cited)." \
  2>/dev/null > /tmp/gemini-dissent.md
source artifacts/db.sh && db_upsert 'research-connector' 'findings' '{NNN}D/{descriptive-name}-dissent' "$(cat /tmp/gemini-dissent.md)" && rm /tmp/gemini-dissent.md
```

Wait for all Phase 2 workers to complete.

### Phase 2 Source Aggregation

After all workers complete, parse Source Tally sections from all findings in the
artifact DB (query `research-connector` / `findings` / `{NNN}D/*`). Aggregate and
store:

```markdown
# Source Tally — Phase 2

| Worker | Track | Queries | Scanned | Cited |
|---|---|---|---|---|
| [descriptive-name] | B (Consensus) | 12 | 87 | 14 |
| [descriptive-name] | C (Codex) | 5 | 34 | 8 |
| [descriptive-name] | D (Gemini) | 8 | 156 | 22 |
| ... | ... | ... | ... | ... |
| **TOTAL** | | **N** | **N** | **N** |

Target: 1000+ scanned
Status: [ON TRACK / SHORTFALL — need N more]
```

Store this tally in the artifact DB:
```bash
source artifacts/db.sh
db_upsert 'meta-deep-research-execute' 'source-tally' '{NNN}D' "$TALLY_CONTENT"
```

## Phase 2.5: Coverage Expansion (MANDATORY)

This phase ALWAYS runs. It is not optional or conditional. The initial research
inevitably surfaces topics, options, and alternatives that weren't in the
original prompt. The debate here is NOT about WHETHER to expand — it's about
WHAT needs expanded research, WHERE the research is thin, and WHICH emergent
tangential topics should be folded in.

### Step 1: Coverage Debate

Launch Opus + Codex reviewers in parallel. Gemini reviewer runs AFTER Track D
completes (sequential — respects the 2-session Gemini hard limit).

Each reads:
- The original `deep_research_prompt.md`
- The dispatch table
- ALL Phase 2 findings files
- The source tally

Their job: identify what's missing, what's thin, and what new threads emerged.

**Reviewer A — Opus subagent** (parallel with Reviewer C):

Spawn an Opus subagent with this prompt:
```
You are a research coverage auditor. This is a MANDATORY expansion phase —
your job is to find what needs MORE research, not to decide if research is
"sufficient." There is ALWAYS more to find.

Read:
1. {research_folder}/deep_research_prompt.md (original scope)
2. {research_folder}/dispatch-table.md (what was planned)
3. All findings files in {research_folder}/ (what was found)
4. {research_folder}/source-tally.md (coverage breadth)

Identify:
- Which original sub-questions have THIN evidence (low source count,
  single-source, low confidence)? These need reinforcement.
- What NEW topics, options, or alternatives surfaced during the research
  that weren't in the original prompt but are clearly relevant? (e.g., a
  competing framework mentioned in 3 sources, an alternative architecture
  pattern, a relevant academic field that keeps appearing)
- Are there well-known approaches, tools, or patterns that practitioners
  would expect to see but the research missed entirely?
- Which connectors underperformed (low result counts)? What different
  queries might yield better results?
- How far is the source count from the 1000+ target? Which tracks should
  contribute more?

Write your assessment and store in the artifact DB:
skill: meta-deep-research-execute, phase: coverage-review, label: {NNN}D/claude

Format:
## Thin Areas Needing Reinforcement
[findings with insufficient evidence — list specific sub-questions]
## Emergent Topics to Research
[topics that surfaced during Phase 2 — each with WHY it's relevant]
## Missed Options/Approaches
[well-known alternatives the research didn't cover]
## Underperforming Connectors
[which connectors need different/additional queries]
## Source Count Gap
[current count vs 1000+ target, which tracks can contribute more]
```

**Reviewer B — Gemini** (runs AFTER Track D Gemini workers complete — sequential):
```bash
# Wait for Track D Gemini workers to finish before starting
unset DEBUG 2>/dev/null
timeout 180 "$GEMINI" --agent generalist -p \
  "You are a research coverage auditor with web access. This is a MANDATORY
   expansion phase — your job is to find what's missing, not to confirm
   things are fine.

   Read the original research prompt and all findings below. Then use web
   search to actively hunt for what the research missed:
   - Search for 'best [topic] alternatives 2026' — what options weren't covered?
   - Search for recent developments (2025-2026) the findings don't mention
   - Search for practitioner criticism of the approaches the research favors
   - Search for adjacent topics that practitioners commonly consider alongside
     the main question

   Original prompt: $(cat {research_folder}/deep_research_prompt.md)
   Findings summary: [compressed key findings from each file]
   Source count: [current total from tally]

   Format:
   ## Missing Options/Approaches (with URLs)
   ## Recent Developments Not Covered (with URLs)
   ## Adjacent Topics Worth Researching
   ## Thin Areas in Current Findings
   ## Source Gaps and Suggested Queries" \
  2>/dev/null > /tmp/coverage-review-gemini.md
source artifacts/db.sh && db_upsert 'meta-deep-research-execute' 'coverage-review' '{NNN}D/gemini' "$(cat /tmp/coverage-review-gemini.md)" && rm /tmp/coverage-review-gemini.md
```

**Reviewer C — Codex** (parallel with Reviewer A — uses reserved slot 5):
```bash
$GTIMEOUT 180 "$CODEX" exec --ephemeral --sandbox read-only \
  --add-dir {research_folder} \
  "You are a technical coverage auditor. This is a MANDATORY expansion
   phase — find what's missing in the research.

   Review the research findings in this directory against the original
   prompt. Identify:
   - Libraries, frameworks, or tools that should have been evaluated
     but weren't (check package registries, awesome-lists, alternatives)
   - Technical claims that are unverified or based on outdated info
   - GitHub repos, official docs, or benchmarks that should be checked
   - Missing comparison dimensions (performance, DX, community size,
     maintenance status, licensing)
   - Technical topics that the findings reference but didn't research

   Format:
   ## Missing Technical Coverage
   ## Unverified Claims to Investigate
   ## Additional Sources to Check (specific repos/docs/benchmarks)
   ## Emergent Technical Topics
   ## Suggested Additional Queries per Connector" \
  2>/dev/null > /tmp/coverage-review-codex.md
source artifacts/db.sh && db_upsert 'meta-deep-research-execute' 'coverage-review' '{NNN}D/codex' "$(cat /tmp/coverage-review-codex.md)" && rm /tmp/coverage-review-codex.md
```

### Step 2: Addendum Creation

Spawn a DIFFERENT Opus subagent (not one that participated in Phase 2 or the
coverage review). This Opus is the impartial judge who synthesizes the three
reviews into a concrete research addendum.

```
You are the research addendum author. You have NOT participated in any prior
research or review — you are fresh eyes.

Read:
1. {research_folder}/deep_research_prompt.md (original scope)
2. {research_folder}/coverage-review-claude.md
3. {research_folder}/coverage-review-gemini.md
4. {research_folder}/coverage-review-codex.md
5. {research_folder}/source-tally.md

This is a MANDATORY expansion. Your job is to write the addendum, not to
decide if one is needed. There is ALWAYS an addendum in deep research.

Synthesize the three coverage reviews and create a prioritized expansion plan:

1. **Thin areas**: Which original sub-questions need more evidence? Assign
   reinforcement queries to specific connectors.

2. **Emergent topics**: Which new topics surfaced across multiple reviewers?
   These are the highest-signal additions — if 2/3 reviewers noticed the
   same gap, it's real.

3. **Missed options**: Well-known alternatives that weren't covered. These
   get full sub-question treatment.

4. **Source count**: If below 1000+, allocate additional query variations
   to the thinnest connectors.

Prioritize ruthlessly — the addendum should be focused, not a kitchen sink.
Rank by impact on the original research question.

Store in the artifact DB:
skill: meta-deep-research-execute, phase: addendum, label: {NNN}D
(Use `db_upsert 'meta-deep-research-execute' 'addendum' '{NNN}D' "$CONTENT"`)

Format:
# Deep Research Addendum — {NNN}D

## Synthesis of Coverage Reviews
[What all three reviewers agreed on vs. where they diverged]

## Reinforcement Targets
[Original sub-questions needing more evidence, with specific new queries]

## New Sub-Questions (from emergent topics)
[Numbered list — each with: question, why it matters to the original
research question, which connectors to use]

## Missed Alternatives to Evaluate
[Options/approaches/tools that should have been in the original research]

## Source Count Plan
Current: [N] scanned | Target: 1000+
[Which tracks and connectors will close the gap]

## Worker Allocation
[Specific track (A/B/C/D) assignments and worker counts]
```

### Step 3: Addendum Research Cycle

The addendum ALWAYS produces additional research. Execute it:

1. **Update the dispatch table.** Read the existing dispatch table from the DB
   (`db_read 'meta-deep-research-execute' 'dispatch-table' '{NNN}D'`), append
   addendum topics with `[ADDENDUM]` tags, then upsert back.

2. **Dispatch additional workers.** Follow the same Phase 2 pattern but ONLY
   for the addendum topics. Use the worker allocation from the addendum.
   Store outputs in the artifact DB with `-addendum` suffix in the label:
   `research-connector` / `findings` / `{NNN}D/{descriptive-name}-addendum`

   All addendum connector subagents MUST follow the multi-query protocol and
   include Source Tally tables.

3. **Update source tally.** Re-aggregate all source tallies (original +
   addendum) from the DB (query all `research-connector` / `findings` /
   `{NNN}D/*`). Add an `## Addendum Sources` section showing the additional
   coverage. Upsert back to `meta-deep-research-execute` / `source-tally` /
   `{NNN}D`.

4. **Max 1 addendum cycle.** To prevent infinite loops, exactly ONE addendum
   cycle runs per deep research invocation. If coverage gaps remain after
   the addendum, note them in the final summary — but do not loop again.

## Phase 3: Cross-Model Debate (3 Rounds)

All debate files go in `{research_folder}/debate/`.

**IMPORTANT**: The debate covers ALL findings — both original Phase 2 AND any
addendum findings. Position papers must reference addendum findings where
relevant.

### Round 1: Present (parallel)

Each model family compiles its Phase 2 (+ addendum) findings into a position paper.

**Claude Position** (Sonnet subagent): Read all Track A + B output files
(including addendum files). For each sub-question: state claim, list evidence
with citations, rate confidence (HIGH/MEDIUM/LOW), flag gaps.

Output stored in artifact DB: `meta-deep-research-execute` / `debate` /
`{NNN}D/position-claude` (written by the Sonnet subagent).

**Codex Position:**
```bash
$GTIMEOUT 180 "$CODEX" exec --ephemeral --sandbox read-only \
  --cd /path/to/project \
  "Read the Codex research findings and compile a position paper.
   Per sub-question: claim, evidence, confidence,
   gaps. If primary and devil's advocate conflict, present BOTH." \
  2>/dev/null > /tmp/debate-position-codex.md
source artifacts/db.sh && db_upsert 'meta-deep-research-execute' 'debate' '{NNN}D/position-codex' "$(cat /tmp/debate-position-codex.md)" && rm /tmp/debate-position-codex.md
```

**Gemini Position:**
```bash
unset DEBUG 2>/dev/null
timeout 180 "$GEMINI" --agent generalist -p \
  "Read these findings and compile a position paper.
   Per sub-question: claim, evidence (URLs), confidence, gaps.
   Where contradiction research disagrees with primary, present BOTH.

   [Pass compressed key findings from DB]" \
  2>/dev/null > /tmp/debate-position-gemini.md
source artifacts/db.sh && db_upsert 'meta-deep-research-execute' 'debate' '{NNN}D/position-gemini' "$(cat /tmp/debate-position-gemini.md)" && rm /tmp/debate-position-gemini.md
```

### Round 2: Challenge (parallel, adversarial)

Each model reads the OTHER two models' positions and attacks them.

**Claude challenges Codex + Gemini** (Sonnet subagent):
Read `position-codex.md` and `position-gemini.md`. Challenge: insufficient
evidence, wrong/outdated technical details, contradictions between them,
missing perspectives, hallucinated claims.

Output stored in artifact DB: `meta-deep-research-execute` / `debate` /
`{NNN}D/challenge-claude` (written by the Sonnet subagent).

**Codex challenges Claude + Gemini:**
```bash
# Read positions from DB first
source artifacts/db.sh
CLAUDE_POS=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/position-claude')
GEMINI_POS=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/position-gemini')
$GTIMEOUT 180 "$CODEX" exec --ephemeral --sandbox read-only \
  "You are a technical fact-checker. Challenge these position papers:
   Claude: $CLAUDE_POS
   Gemini: $GEMINI_POS

   Focus on: wrong library claims, unsourced performance claims,
   incorrect API behavior, architecture that won't scale." \
  2>/dev/null > /tmp/debate-challenge-codex.md
db_upsert 'meta-deep-research-execute' 'debate' '{NNN}D/challenge-codex' "$(cat /tmp/debate-challenge-codex.md)" && rm /tmp/debate-challenge-codex.md
```

**Gemini challenges Claude + Codex:**
```bash
unset DEBUG 2>/dev/null
source artifacts/db.sh
CLAUDE_POS=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/position-claude')
CODEX_POS=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/position-codex')
timeout 180 "$GEMINI" --agent generalist -p \
  "You are a fact-checker with web access. Verify or challenge:
   Claude: $CLAUDE_POS
   Codex: $CODEX_POS

   Per major claim: search the web, mark as CONFIRMED / DISPUTED /
   UNVERIFIABLE with sources. Focus on recency — other models may
   have outdated training data." \
  2>/dev/null > /tmp/debate-challenge-gemini.md
db_upsert 'meta-deep-research-execute' 'debate' '{NNN}D/challenge-gemini' "$(cat /tmp/debate-challenge-gemini.md)" && rm /tmp/debate-challenge-gemini.md
```

### Round 3: Respond + Converge (parallel)

Each model reads challenges against its position and responds with one of:
- **Concede**: "Valid. Updating position to [new position]."
- **Rebut**: "Original claim stands because [additional evidence]."
- **Escalate**: "Insufficient evidence either way. Flagging as unresolved."

**Claude responds** (Sonnet subagent): reads challenges from DB (`{NNN}D/challenge-codex`
and `{NNN}D/challenge-gemini`). Stores output in artifact DB:
`meta-deep-research-execute` / `debate` / `{NNN}D/response-claude`.

**Codex responds:**
```bash
source artifacts/db.sh
CODEX_POS=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/position-codex')
CLAUDE_CHAL=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/challenge-claude')
GEMINI_CHAL=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/challenge-gemini')
$GTIMEOUT 180 "$CODEX" exec --ephemeral --sandbox read-only \
  "Read challenges against your position and respond per claim:
   CONCEDE / REBUT / ESCALATE with evidence.

   Your position: $CODEX_POS
   Claude's challenges: [extract Codex-targeted from: $CLAUDE_CHAL]
   Gemini's challenges: [extract Codex-targeted from: $GEMINI_CHAL]" \
  2>/dev/null > /tmp/debate-response-codex.md
db_upsert 'meta-deep-research-execute' 'debate' '{NNN}D/response-codex' "$(cat /tmp/debate-response-codex.md)" && rm /tmp/debate-response-codex.md
```

**Gemini responds:**
```bash
unset DEBUG 2>/dev/null
source artifacts/db.sh
GEMINI_POS=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/position-gemini')
CLAUDE_CHAL=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/challenge-claude')
CODEX_CHAL=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/challenge-codex')
timeout 180 "$GEMINI" --agent generalist -p \
  "Read challenges against your position. Use fresh web searches for
   additional evidence. Respond per claim: CONCEDE / REBUT / ESCALATE.

   Your position: $GEMINI_POS
   Claude's challenges: [extract Gemini-targeted from: $CLAUDE_CHAL]
   Codex's challenges: [extract Gemini-targeted from: $CODEX_CHAL]" \
  2>/dev/null > /tmp/debate-response-gemini.md
db_upsert 'meta-deep-research-execute' 'debate' '{NNN}D/response-gemini' "$(cat /tmp/debate-response-gemini.md)" && rm /tmp/debate-response-gemini.md
```

## Phase 4: Convergence Scoring

Read ALL 9 debate files. Score every major claim using extended thinking.

**Confidence levels by debate outcome:**

| Outcome | Confidence | Meaning |
|---|---|---|
| 3/3 agree after debate | **VERIFIED** | Highest trust |
| 2/3 agree, 1 conceded | **HIGH** | Debate resolved |
| 2/3 agree, 1 rebutted with evidence | **CONTESTED** | Majority + documented dissent |
| All 3 hold different positions | **UNCERTAIN** | Present all, flag for human |
| Claim challenged, no model could rebut | **DEBUNKED** | Hallucination caught |
| All 3 escalated | **UNRESOLVED** | Honest evidence gap |

**Rules:**
- VERIFIED -> report as facts
- HIGH -> report with concession note
- CONTESTED -> report BOTH sides, let user decide
- UNCERTAIN -> "Open Questions" section
- DEBUNKED -> debate trail only
- UNRESOLVED -> "Gaps" section with follow-up suggestions

**Source quality weighting:**
Academic papers > official docs > engineering blogs > forums > LLM inference.
2025-2026 sources weighted higher for fast-moving fields. First-hand experience
(case studies, postmortems) weighted higher than theory.

Store scoring results in the artifact DB:
```bash
source artifacts/db.sh
db_upsert 'meta-deep-research-execute' 'convergence-scoring' '{NNN}D' "$SCORING_CONTENT"
```

## Phase 5: Write Summary

Write the final summary to `artifacts/research/summary/{NNN}D-{topic-slug}.md`.
Create `artifacts/research/summary/` if it doesn't exist. This is the only
file output — all intermediate artifacts are in the artifact DB.

**Summary structure (300-500 lines):**

```markdown
# Deep Research: {Topic}

> Research folder: research/{NNN}D/
> Date: {DATE}
> Models: Opus 4.6 (orchestrator), Sonnet 4.6 ({N} subagents),
>   Codex gpt-5.3 ({N} workers), Gemini 3.1 Pro ({N} instances)
> MCP connectors used: {LIST}
> Debate rounds: 3
> Addendum cycle: [yes — {reason} | no]
> Sources: {N} queries | {N} scanned | {N} cited
> Claims: {N} verified, {N} high, {N} contested, {N} debunked

## Executive Summary

[10-15 bullets — highest-confidence findings only. Each states the claim,
its confidence level, and model agreement.]

## Confidence Map

| # | Sub-Question | Confidence | Agreement | Finding |
|---|---|---|---|---|
| 1 | [question] | VERIFIED | 3/3 | [one-line answer] |
| 2 | [question] | CONTESTED | 2/3 | [majority position] |

## Detailed Findings

### SQ-1: [Sub-Question]

**Confidence**: VERIFIED / HIGH / CONTESTED / UNCERTAIN / UNRESOLVED
**Agreement**: Which models agree, which dissent

**Finding**: [synthesized answer]

**Evidence**:
- Claude: [evidence with citations]
- Codex: [evidence with citations]
- Gemini: [evidence with URLs]

**Debate**: [how the claim evolved through 3 rounds]

[Repeat per sub-question]

## Addendum Findings

[If an addendum cycle ran, summarize what it added. Reference the coverage
review that triggered it and the new evidence gathered.]

### Emergent Topic: [Name]
**Why it surfaced**: [which connector/worker found it]
**Finding**: [what we learned]
**Impact on original question**: [how this changes the answer]

## Contested Findings

[Claims where models disagreed after debate. Present BOTH sides.]

### [Contested Claim]
**Majority** ({models}): [claim + evidence]
**Dissent** ({model}): [counter-claim + evidence]
**Impact**: [why this matters for the user's decision]

## Open Questions

[UNCERTAIN or UNRESOLVED claims. Include suggested follow-up.]

## Debunked Claims

[Claims confidently stated in Round 1 that didn't survive challenge.
These are the hallucinations caught by debate.]

## Source Index

### Academic Sources
[Papers from Consensus, Scholar Gateway, PubMed]

### Official Documentation
[From Context7, MS Learn, GitHub]

### Web Sources
[From Gemini, WebSearch — with URLs]

### Code Evidence
[From Codex, GitHub search]

### Source Tally
[Final aggregate from artifact DB (meta-deep-research-execute / source-tally / {NNN}D) — queries, scanned, cited by track]

## Methodology

[Brief: worker allocation, debate structure, confidence scoring,
whether addendum cycle ran and why.
Intermediate artifacts available in artifact DB under
`meta-deep-research-execute` and `research-connector` skills, all labels
prefixed with `{NNN}D/`.]
```

## Phase 6: Report Completion

After writing the summary, report back to the dispatching Claude with ONLY:
- The summary file path
- Source tally: {N} queries | {N} scanned | {N} cited
- Claim counts: verified / high / contested / debunked
- Whether an addendum cycle ran (and what it added)
- Any CONTESTED findings needing human judgment (one line each)

Keep the report-back minimal — the dispatcher reads the full summary itself.

## Error Handling

- **Gemini unavailable**: Use WebSearch for Track D. Debate becomes 2-model.
- **Codex unavailable**: Redistribute to Sonnet subagents. Debate becomes 2-model.
- **Both unavailable**: All research through Claude. Replace debate with
  self-consistency (3 independent Sonnet subagents, flag disagreements).
  Note "single-model" in methodology.
- **Subagent failure**: Note the gap. Mark affected claims as UNCERTAIN.
- **Debate timeout**: Proceed with available responses. 2-model debate is
  still better than none.
- **Coverage review failure**: If any reviewer fails in Phase 2.5, proceed
  with available reviews. The addendum author works with whatever reviews
  completed. If ALL reviewers fail, write a minimal addendum targeting only
  source count gaps and proceed to debate.
- **Addendum cycle**: Exactly 1 cycle, mandatory. If coverage gaps remain
  after the addendum, note them in the summary but do not loop again.

## Concurrency Limits (HARD CONSTRAINTS)

These limits reflect the user's actual subscription/platform caps:

| CLI | Max Concurrent | Allocation |
|---|---|---|
| **Codex** | **5 sessions** | 4 Phase 2 workers + 1 reserved for Phase 2.5/3 |
| **Gemini** | **2 sessions** | 2 Phase 2 instances; Phase 2.5/3 run AFTER Phase 2 completes (sequential) |

**Rules:**
- NEVER exceed these limits. If a phase needs more, run sequentially.
- Track D (Gemini) must fully complete before Phase 2.5 Gemini reviewer starts.
- Track C (Codex) workers 1-4 must fully complete before Phase 2.5 Codex reviewer starts.
- Debate rounds are already sequential (1 Codex + 1 Gemini per round), so no conflict.
- Addendum cycle reuses the same slots after prior workers complete.

## Cost Awareness

This skill is expensive. ~17 workers + mandatory coverage expansion + addendum
workers + 3 debate rounds.

- Opus subagents: 2-3 x ~100K tokens each (Phase 2) + 1 coverage reviewer
  + 1 addendum author = up to 5 Opus subagents
- Sonnet subagents: 8-10 x ~50K tokens each + addendum connectors
- Codex workers: up to 4 concurrent (of 5 max) + 1 reserved for coverage/debate
- Gemini instances: 2 concurrent (of 2 max); coverage/debate run sequential
- Debate rounds: 3 x 3 models x ~30K tokens each (sequential per round)

Reserve for decisions where being wrong costs more than the research.
