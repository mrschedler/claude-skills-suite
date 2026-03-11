---
name: meta-review
description: Comprehensive multi-model project review across 7 lenses and 3 model families in parallel. Use for full project review, pre-deploy audit, or milestone quality gate. Not for single-lens reviews.
---

# meta-review

Meta-skill that fans out 7 review lenses across 3 model families in parallel,
then synthesizes findings into a unified report with confidence scoring.

## Architecture

Sonnet-primary with targeted Codex/Gemini spot-checks on key lenses.

```
                   +-- counter-review ----[Sonnet | Gemini]
                   +-- security-review ---[Sonnet | Codex]
                   +-- test-review ------[Sonnet]
meta-review --> +-- refactor-review ---[Sonnet | Codex]       --> synthesis
                   +-- drift-review -----[Sonnet | Gemini]
                   +-- completeness-review -[Sonnet | Codex]
                   +-- compliance-review -[Sonnet]
```

Total: **12 reviews** (7 Sonnet + 3 Codex + 2 Gemini), then 1 synthesis pass.

**Model assignment rationale:**
- **Sonnet** (all 7): primary reviewer, full codebase access, no concurrency limit
- **Codex** (security, refactor, completeness): code-centric lenses where static analysis shines
- **Gemini** (counter, drift): architecture/strategy lenses that benefit from web grounding

## Inputs

| Input | Source | Required |
|---|---|---|
| Project root path | cwd or user prompt | Yes |
| project-context.md | Project root | Yes |
| features.md | Project root | Yes |
| project-plan.md | Project root | Recommended |
| Full codebase | Project root | Yes |

## Outputs

- 7 x 3 = 21 individual lens findings in the artifact DB (skill=`{lens}`, phase=`findings`, label=`sonnet`/`codex`/`gemini`)
- 1 unified synthesis on disk: `artifacts/reviews/review-synthesis.md`

## Instructions

### Phase 1: Preparation

1. Verify the project has the required inputs. If `project-context.md` or
   `features.md` is missing, stop and tell the user to create them first
   (run `/meta-init` or the individual atomic skills).

2. Create the `artifacts/reviews/` directory if it does not exist.

3. Check CLI availability for multi-model execution:
   ```bash
   CODEX=$(ls ~/.nvm/versions/node/*/bin/codex 2>/dev/null | sort -V | tail -1)
   test -x "$CODEX" || CODEX="/opt/homebrew/bin/codex"
   GTIMEOUT="/opt/homebrew/bin/gtimeout"; test -x "$GTIMEOUT" || GTIMEOUT="/opt/homebrew/bin/timeout"
   test -x "$CODEX" && echo "codex: available" || echo "codex: unavailable"
   which gemini >/dev/null 2>&1 && echo "gemini: available" || echo "gemini: unavailable"
   ```
   Note which models are available. Unavailable models are skipped — the
   synthesis adjusts confidence scoring accordingly (2-model max instead of 3).

4. Identify the ~10 most important source files for Gemini context. These
   are typically: entry point, main config, core business logic files, auth
   module, database layer, and any file >200 lines. Write this file list —
   Gemini invocations will reference them via `@path/to/file`.

### Phase 2: Fan-Out (12 reviews total)

The 7 review lenses with their model assignments:

| Lens | Atomic Skill | Sonnet | Codex | Gemini |
|---|---|---|---|---|
| counter-review | `/counter-review` | YES | — | YES |
| security-review | `/security-review` | YES | YES | — |
| test-review | `/test-review` | YES | — | — |
| refactor-review | `/refactor-review` | YES | YES | — |
| drift-review | `/drift-review` | YES | — | YES |
| completeness-review | `/completeness-review` | YES | YES | — |
| compliance-review | `/compliance-review` | YES | — | — |

**Do NOT add lenses to Codex or Gemini beyond what is listed above.**
Sonnet covers all 7. Codex covers 3. Gemini covers 2. Total = 12 reviews.

---

#### Step 2a: Launch Sonnet subagents (all 7 at once — OK)

Spawn the `review-lens` agent (`subagent_type: "review-lens"`) for each lens.
All 7 can run simultaneously — Sonnet subagents have no concurrency limit.

Each agent:
1. Receives the lens name and the atomic skill's review instructions in the prompt
2. Has full codebase access via Claude tools
3. Uses standardized severity classification and output format
4. Returns findings as text in its response — does NOT write to DB

**DB writes are the main thread's job.** When each subagent returns, the
main thread extracts the findings from the agent's response and writes
them to the artifact DB:
```bash
source artifacts/db.sh
db_upsert '{lens}' 'findings' 'sonnet' "$AGENT_RESPONSE"
```
Subagents do NOT have access to `artifacts/db.sh` or the project DB path.
Never rely on subagents to write to the DB — they will silently fail.

#### Step 2b: Launch Codex (3 lenses — all 3 at once)

Use the `/codex` skill for invocation syntax.

Launch exactly **3** Codex processes for: `security-review`, `refactor-review`,
`completeness-review`. All 3 fit within the 5-slot limit — no queuing needed.

Each Codex exec:
1. Receives a review prompt assembled from the atomic skill's instructions
2. Runs with `--sandbox read-only --ephemeral` and relevant source directories
   via `--add-dir`
3. Pipes output to a temp file, then stores in DB:
   ```bash
   $GTIMEOUT 120 "$CODEX" exec --skip-git-repo-check ... 2>/dev/null > /tmp/lens-codex-{lens}.md
   source artifacts/db.sh && db_upsert '{lens}' 'findings' 'codex' "$(cat /tmp/lens-codex-{lens}.md)" && rm /tmp/lens-codex-{lens}.md
   ```

If Codex is unavailable, skip all Codex reviews and note it in synthesis.

#### Step 2c: Launch Gemini (2 lenses — both at once)

Use the `/gemini` skill for invocation syntax and environment safety.

Launch exactly **2** Gemini processes for: `counter-review`, `drift-review`.
Both fit within the 2-slot limit — no queuing needed.

Each Gemini invocation:
1. Receives a prompt file containing: the atomic skill's review instructions
   plus relevant code context via `@path/to/file` references (use the file
   list from Phase 1, max ~10 files per invocation)
2. Uses `codebase_investigator` sub-agent
3. Runs with `--agent codebase_investigator`, `$GTIMEOUT 60`, and `2>/dev/null`
4. Pipes output to a temp file, then stores in DB as label `gemini`:
   ```bash
   $GTIMEOUT 60 "$GEMINI" ... 2>/dev/null > /tmp/lens-gemini-{lens}.md
   source artifacts/db.sh && db_upsert '{lens}' 'findings' 'gemini' "$(cat /tmp/lens-gemini-{lens}.md)" && rm /tmp/lens-gemini-{lens}.md
   ```

If Gemini is unavailable, skip all Gemini reviews and note it in synthesis.

**Steps 2a, 2b, and 2c can all launch simultaneously** — there is no
queuing needed since counts are within limits (7 Sonnet, 3 Codex, 2 Gemini).

---

### Phase 3: Wait for Completion

All 12 reviews must complete before synthesis begins:

- Sonnet: confirm all 7 subagents returned
- Codex: confirm 3/3 via DB: `source artifacts/db.sh && db_exists '{lens}' 'findings' 'codex'` for security, refactor, completeness
- Gemini: confirm 2/2 via DB: `source artifacts/db.sh && db_exists '{lens}' 'findings' 'gemini'` for counter, drift

If any individual review fails (timeout, crash, empty output), note the
failure in synthesis but do not block on it. Partial data is better than no
data.

### Phase 4: Synthesis

After all reviews complete, read lens findings from the artifact DB. Each
lens has a different number of models — read only what was assigned:

```bash
source artifacts/db.sh
# All 7 lenses have Sonnet
SONNET=$(db_read '{lens}' 'findings' 'sonnet')
# security, refactor, completeness also have Codex
CODEX=$(db_read '{lens}' 'findings' 'codex')    # only for 3 lenses
# counter, drift also have Gemini
GEMINI=$(db_read '{lens}' 'findings' 'gemini')   # only for 2 lenses
```

Synthesize into `artifacts/reviews/review-synthesis.md` (this file STAYS on disk — it is the final output).

The synthesis document structure:

#### Confidence Scoring

Confidence depends on how many models reviewed that lens:

| Lens Coverage | Agreement | Confidence |
|---|---|---|
| 2-model lens (Sonnet + Codex/Gemini) | 2/2 agree | **HIGH** |
| 2-model lens | 1/2 flags it | **MEDIUM** |
| 1-model lens (Sonnet only) | Sonnet flags it | **MEDIUM** (no cross-validation) |

For findings that appear across multiple lenses (cross-lens patterns),
confidence is automatically HIGH regardless of per-lens model count.

#### Deduplication

Different models will find the same issue with different wording. Merge
duplicates into a single finding, noting which models flagged it.

#### Cross-Lens Patterns

Look for patterns that span multiple lenses:
- A security finding + a test finding about the same code = high-priority gap
- A drift finding + a completeness finding = likely a feature that was
  partially implemented and then abandoned
- A refactor finding + a counter-review finding = structural issue
  masquerading as multiple smaller problems

Flag cross-lens patterns explicitly — they are higher priority than any
single-lens finding.

#### Synthesis Document Structure

```markdown
# Review Synthesis

## Summary
- Total findings: N (after dedup)
- By confidence: HIGH: X, MEDIUM: Y
- Reviews completed: 12 (7 Sonnet + 3 Codex + 2 Gemini), note any failures
- Multi-model lenses: security, refactor, completeness (Codex), counter, drift (Gemini)

## Cross-Lens Patterns
[Patterns that span multiple review lenses — highest priority items]

## HIGH Confidence Findings
[Findings flagged by all available models — sorted by severity]

## MEDIUM Confidence Findings
[Findings flagged by 2 of 3 models — sorted by severity]

## Notable LOW Confidence Findings
[Only CRITICAL/HIGH severity findings from a single model — may be
false positives but too important to ignore]

## Per-Lens Summary
[One-paragraph summary per lens with finding counts]

## Recommendations
[Prioritized action list: what to fix first, what can wait, what to ignore]
```

### Phase 5: Report

Present the synthesis to the user. Highlight:
- Total finding count and confidence distribution
- Top 3 highest-priority items (cross-lens patterns first)
- Whether any lenses found zero issues (suspicious — may indicate the
  review prompt was too narrow or the model hallucinated "all clear")

After presenting, suggest: **"Run `/review-fix` to implement approved fixes."**

## Error Handling

- If a model is unavailable, run with remaining models. Adjust confidence
  scoring denominators accordingly.
- If an entire lens fails across all models, flag it as "REVIEW FAILED" in
  synthesis and recommend the user run that lens manually.
- If the project is small (< 5 source files), warn the user that some lenses
  (refactor, compliance) may produce thin results — this is expected, not a
  failure.

## Examples

```
User: "Run a full review before we deploy."
Action: Verify inputs exist. Fan out all 7 lenses x 3 models in parallel.
        Wait for completion. Synthesize. Present prioritized findings.
```

```
User: "Project review — we just finished the MVP."
Action: Same full fan-out. Emphasize completeness-review and drift-review
        since MVP milestones are where planned vs. actual diverge most.
```

```
User: "Audit everything. I don't trust this codebase."
Action: Full review. Call out any lens where all 3 models agree there are
        CRITICAL issues — those are the trust-breakers to address first.
```

```
User: [After meta-init] "Run the review before I start building."
Action: Full review focused on the plan and context docs rather than code
        (since code doesn't exist yet). Counter-review, completeness-review,
        and drift-review are most relevant at this stage.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
