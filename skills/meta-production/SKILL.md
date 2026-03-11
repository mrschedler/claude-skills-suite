---
name: meta-production
description: Scored production readiness assessment (READY / CONDITIONAL / NOT READY) across 10 dimensions. Use when asking "can we ship this?" Outputs artifacts/reviews/production-readiness.md.
---

# meta-production

Production Readiness Review (PRR) — a scored, evidence-backed assessment of
whether a project is safe to deploy to production. Inspired by Google SRE's
PRR framework, Cortex production readiness scorecards, and DORA metrics.

## Chain

```
[Phase 1: Stack Research]     Gemini — production patterns for this stack
[Phase 2: Parallel Scan]      7 review lenses (Sonnet) + production antipattern scan (Codex)
[Phase 3: Scoring]            Claude — score 10 dimensions from Phase 1-2 findings
[Phase 4: Report]             Write artifacts/reviews/production-readiness.md with verdict
```

## Inputs

| Input | Source | Required |
|---|---|---|
| project-context.md | Project root | Yes |
| features.md | Project root | Yes |
| project-plan.md | Project root | No |
| Source code | `src/` or equivalent | Yes |
| Existing review findings | Artifact DB (lens findings) | No (reused if fresh) |

## Scoring System

### 10 Dimensions (0-10 each, 100 total)

| # | Dimension | What It Measures | Primary Source |
|---|---|---|---|
| 1 | **Code Completeness** | No stubs, TODOs, placeholders, incomplete implementations | completeness-review |
| 2 | **Code Quality** | No duplication, consistent patterns, no over-engineering, no truncation | refactor-review |
| 3 | **Security** | No secrets, deps audited, auth solid, input validated, OWASP covered | security-review |
| 4 | **Testing** | Coverage adequate, no stub tests, error paths tested, no fragile tests | test-review |
| 5 | **Documentation Sync** | Docs match code, no drift in either direction | drift-review |
| 6 | **Compliance** | Codebase follows its own documented rules | compliance-review |
| 7 | **Architecture** | Stack justified, no circular deps, scaling considered, resilient | counter-review |
| 8 | **Observability** | Logging, metrics, tracing, health endpoints, alerting | Production scan |
| 9 | **Deployment** | Rollback strategy, env config, graceful shutdown, container hygiene | Production scan |
| 10 | **Operations** | Runbooks, error handling, rate limiting, resource limits, incident readiness | Production scan |

### Scoring Rubric Per Dimension

| Score | Meaning |
|---|---|
| 9-10 | Excellent — production-grade, no issues |
| 7-8 | Good — minor issues, none blocking |
| 5-6 | Acceptable — notable gaps but workable with known risks |
| 3-4 | Concerning — significant gaps that need addressing |
| 1-2 | Poor — critical issues, not safe for production |
| 0 | Missing — dimension not addressed at all |

### Verdict Thresholds

| Total Score | Verdict | Meaning |
|---|---|---|
| 85-100 | **PRODUCTION READY** | Ship it. Minor items can be addressed post-launch. |
| 70-84 | **CONDITIONALLY READY** | Can ship if listed conditions are met first. |
| 50-69 | **NOT READY** | Significant work required. Remediation plan provided. |
| 0-49 | **BLOCKED** | Critical failures. Do not deploy under any circumstances. |

**Override rule**: Any single dimension scoring 0-2 forces a maximum verdict
of CONDITIONALLY READY regardless of total score. A single critical gap can
sink a deployment.

## Instructions

### Phase 1: Stack Research (Gemini)

Before scanning code, research production best practices specific to this
project's tech stack. Read `project-context.md` to identify the stack, then
dispatch Gemini to research production hardening for it.

```bash
GEMINI="/Users/trevorbyrum/.npm-global/bin/gemini"
test -x "$GEMINI" || GEMINI="/opt/homebrew/bin/gemini"
test -x "$GEMINI" || { echo "Gemini unavailable — skipping stack research"; }
```

If Gemini is available, run:

```bash
unset DEBUG 2>/dev/null
timeout 120 "$GEMINI" --agent generalist -p \
  "Research production readiness best practices for a [STACK] application.
   Cover: deployment patterns, observability requirements, security hardening,
   performance tuning, graceful shutdown, health checks, and common production
   antipatterns. Be specific to this stack — not generic advice.
   Project context: [first 3 sections of project-context.md]" \
  2>/dev/null > /tmp/prr-stack-research.md
```

Replace `[STACK]` with the actual tech stack from project-context.md.

If Gemini is unavailable, use Claude WebSearch to research the same topics.
Stack research is NOT optional — the production-specific checks in Phase 2
use these findings to know what to look for.

### Phase 2: Parallel Scan

Fan out all scans simultaneously. Three tracks run in parallel:

#### Track A: Review Lenses (7 Sonnet Subagents)

Check the artifact DB for fresh lens findings:

```bash
source artifacts/db.sh
AGE=$(db_age_hours 'security-review' 'findings' 'sonnet')
# Repeat for other lenses
```

If `$AGE` is non-empty and < 24, reuse those findings instead of re-running that lens.

For each lens that needs running, spawn a Sonnet subagent using the
`review-lens` agent (`subagent_type: "review-lens"`). Pass each lens its
specific instructions from the corresponding skill:

1. `completeness-review` → Dimension 1
2. `refactor-review` → Dimension 2
3. `security-review` → Dimension 3
4. `test-review` → Dimension 4
5. `drift-review` → Dimension 5
6. `compliance-review` → Dimension 6
7. `counter-review` → Dimension 7

Each review-lens subagent stores its output in DB as `db_upsert '{lens}' 'findings' 'sonnet' "$CONTENT"`.

#### Track B: Production Antipattern Scan (3 Codex Workers)

Fan out 3 Codex instances in parallel — one per production dimension.
Each gets a focused, single-dimension prompt for deeper analysis than a
monolithic scan. Uses 3 of the 5 available Codex slots (leaving 2 free
for other work).

```bash
CODEX=$(ls ~/.nvm/versions/node/*/bin/codex 2>/dev/null | sort -V | tail -1)
test -x "$CODEX" || CODEX="/opt/homebrew/bin/codex"
test -x "$CODEX" || { echo "Codex unavailable — falling back to Sonnet"; }
```

Read `references/production-scan-prompts.md` for the full prompt text for
each worker. If Codex is available, launch all 3 in parallel:

**Codex Worker 1 — Observability (Dimension 8):**

```bash
timeout 120 "$CODEX" exec --ephemeral --sandbox read-only \
  --cd /path/to/project \
  "[observability prompt from references/production-scan-prompts.md]" \
  2>/dev/null > /tmp/prr-observability.md &
CODEX_PID_1=$!
```

**Codex Worker 2 — Deployment (Dimension 9):**

```bash
timeout 120 "$CODEX" exec --ephemeral --sandbox read-only \
  --cd /path/to/project \
  "[deployment prompt from references/production-scan-prompts.md]" \
  2>/dev/null > /tmp/prr-deployment.md &
CODEX_PID_2=$!
```

**Codex Worker 3 — Operations (Dimension 10):**

```bash
timeout 120 "$CODEX" exec --ephemeral --sandbox read-only \
  --cd /path/to/project \
  "[operations prompt from references/production-scan-prompts.md]" \
  2>/dev/null > /tmp/prr-operations.md &
CODEX_PID_3=$!
```

Wait for all 3 Codex workers and store results in DB:

```bash
wait $CODEX_PID_1
source artifacts/db.sh
db_upsert 'meta-production' 'scan' 'observability' "$(cat /tmp/prr-observability.md)"
rm /tmp/prr-observability.md

wait $CODEX_PID_2
db_upsert 'meta-production' 'scan' 'deployment' "$(cat /tmp/prr-deployment.md)"
rm /tmp/prr-deployment.md

wait $CODEX_PID_3
db_upsert 'meta-production' 'scan' 'operations' "$(cat /tmp/prr-operations.md)"
rm /tmp/prr-operations.md
```

If Codex is unavailable, run these 3 checks as Sonnet subagents instead.
Less depth but still covers the patterns via grep and file analysis.

#### Track C: Production Research Cross-Reference (Gemini)

While Track A and B run, have Gemini cross-reference the stack research
(Phase 1) against the project's actual implementation:

```bash
unset DEBUG 2>/dev/null
timeout 120 "$GEMINI" --agent codebase_investigator -p \
  "Compare these production best practices against the actual codebase.
   For each practice, mark it as: IMPLEMENTED, PARTIALLY IMPLEMENTED,
   or MISSING. Cite specific files and lines.
   Best practices: $(cat /tmp/prr-stack-research.md)
   Focus on the top 20 most critical practices for this stack." \
  2>/dev/null > /tmp/prr-practices.md
source artifacts/db.sh
db_upsert 'meta-production' 'scan' 'practices-audit' "$(cat /tmp/prr-practices.md)"
rm /tmp/prr-practices.md
```

Stack research (`/tmp/prr-stack-research.md`) can remain a temp file — it's consumed immediately and doesn't need persistence.

If Gemini is unavailable, skip this track. It enriches the report but
isn't required for scoring.

### Phase 3: Scoring

After all Phase 2 scans complete, score each dimension.

**For Dimensions 1-7** (review lenses):

Read lens findings from the artifact DB:

```bash
source artifacts/db.sh
COMPLETENESS=$(db_read 'completeness-review' 'findings' 'sonnet')
REFACTOR=$(db_read 'refactor-review' 'findings' 'sonnet')
SECURITY=$(db_read 'security-review' 'findings' 'sonnet')
TEST=$(db_read 'test-review' 'findings' 'sonnet')
DRIFT=$(db_read 'drift-review' 'findings' 'sonnet')
COMPLIANCE=$(db_read 'compliance-review' 'findings' 'sonnet')
COUNTER=$(db_read 'counter-review' 'findings' 'sonnet')
```

Score based on:

| Findings | Score |
|---|---|
| 0 CRITICAL, 0 HIGH | 9-10 |
| 0 CRITICAL, 1-2 HIGH | 7-8 |
| 0 CRITICAL, 3+ HIGH or 1 CRITICAL | 5-6 |
| 2+ CRITICAL or 5+ HIGH | 3-4 |
| 3+ CRITICAL | 1-2 |
| Lens not run / no data | 0 |

Adjust within the range based on MEDIUM/LOW count and finding severity.

**For Dimensions 8-10** (production scans):

Read each dimension's scan from the artifact DB:

```bash
source artifacts/db.sh
OBSERVABILITY=$(db_read 'meta-production' 'scan' 'observability')
DEPLOYMENT=$(db_read 'meta-production' 'scan' 'deployment')
OPERATIONS=$(db_read 'meta-production' 'scan' 'operations')
PRACTICES=$(db_read 'meta-production' 'scan' 'practices-audit')
```

Each Codex worker focused on a single dimension, so findings map 1:1. Score based on:

| Findings | Score |
|---|---|
| Category fully addressed, patterns implemented | 9-10 |
| Most items addressed, 1-2 minor gaps | 7-8 |
| Some items addressed, notable gaps | 5-6 |
| Few items addressed, significant gaps | 3-4 |
| Category barely addressed | 1-2 |
| No evidence of any production consideration | 0 |

**Cross-validation**: Compare each Codex worker's findings against the
Gemini practices audit (Track C) for the same dimension. If they
contradict, investigate the discrepancy before finalizing the score.
The more conservative (lower) score wins unless you can verify the
optimistic assessment. When both Codex and Gemini agree on an issue,
boost its confidence to HIGH.

### Phase 4: Report

Read `references/report-template.md` for the full report structure, then
write `artifacts/reviews/production-readiness.md` following that template.

### Post-Report

After writing the report, present the user with:

1. The verdict and total score
2. The scorecard table
3. The critical blockers (if any)
4. Top 3 remediation items

Then offer next steps:

> "Production readiness assessment complete.
>
> 1. **Fix blockers** — address the P0 items and re-run `/meta-production`
> 2. **Detailed dive** — review a specific dimension in depth
> 3. **Accept risk** — proceed to deployment with documented gaps
> 4. **Full review** — run `/meta-review` for the complete 21-review sweep"

## Reuse of Existing Reviews

Check the artifact DB for fresh lens findings using `db_age_hours`. For each lens:

```bash
source artifacts/db.sh
AGE=$(db_age_hours '{lens}' 'findings' 'sonnet')
```

If `$AGE` is non-empty and < 24, reuse that lens's findings instead of re-running it.
This allows the user to run `/meta-review` first for the full 21-review treatment,
then run `/meta-production` which picks up those findings from the DB and adds the
production-specific dimensions (8-10) and scoring.

If existing findings are older than 24 hours (or absent), re-run those lenses — the
codebase may have changed.

## Error Handling

- If Gemini is unavailable: use Claude WebSearch for stack research (Phase 1),
  skip Track C (practices audit). Note in methodology section.
- If Codex is unavailable: run production antipattern checks as a Sonnet
  subagent instead. Note reduced scan depth in methodology.
- If both are unavailable: all scans run via Sonnet subagents. The report
  is still valid but note "single-model assessment" in methodology and
  reduce confidence in Dimensions 8-10 scoring.
- If a review lens fails: score that dimension 0 and note "assessment
  incomplete" in the scorecard.

## Examples

```
User: "Is this ready for production?"
Action: Read project-context.md for stack. Phase 1 — Gemini researches
        production patterns for the stack. Phase 2 — fan out 7 review lenses
        + Codex antipattern scan + Gemini practices audit. Phase 3 — score
        all 10 dimensions. Phase 4 — write artifacts/reviews/production-readiness.md. Present
        verdict and scorecard.
```

```
User: "/meta-production"
Action: Full PRR flow. All 4 phases.
```

```
User: "We already ran a full review, just check production readiness"
Action: Check artifact DB for fresh lens findings (db_age_hours < 24). Reuse them
        for Dimensions 1-7. Run only the production-specific scans (Codex + Gemini) for
        Dimensions 8-10. Score and report.
```

```
User: "Re-check production readiness after fixing the blockers"
Action: Re-run only the dimensions that scored below 7. Reuse passing
        dimensions from the previous report. Update artifacts/reviews/production-readiness.md
        with new scores and revised verdict.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
