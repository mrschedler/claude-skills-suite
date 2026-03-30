---
name: meta-production
description: Scored production readiness assessment (READY / CONDITIONAL / NOT READY) across 12 dimensions. Use when asking "can we ship this?" Outputs artifacts/reviews/production-readiness.md.
---

# meta-production

Scored production readiness assessment across 12 dimensions.

## Chain

```
[Phase 1: Stack Research]     Gemini — production patterns for this stack
[Phase 2: Parallel Scan]      7 review lenses (Sonnet) + production scan (5 Codex)
[Phase 3: Scoring]            Claude — score 12 dimensions from Phase 1-2 findings
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

## Scoring

12 dimensions (0-10 each, 120 total). Read `references/scoring-rubric.md` for
full rubric, criticality tiers, and verdict thresholds.

| # | Dimension | Primary Source |
|---|---|---|
| 1 | Code Completeness | completeness-review |
| 2 | Code Quality | refactor-review |
| 3 | Security | security-review |
| 4 | Testing | test-review |
| 5 | Documentation Sync | drift-review |
| 6 | Compliance | compliance-review |
| 7 | Architecture | counter-review |
| 8 | Observability | Production scan |
| 9 | Deployment | Production scan |
| 10 | Operations | Production scan |
| 11 | Reliability | Production scan |
| 12 | Capacity | Production scan |

**Verdicts**: PRODUCTION READY (85%+), CONDITIONALLY READY (70-84%), NOT READY (50-69%), BLOCKED (<50%).
**Override**: Any dimension scoring 0-2 caps verdict at CONDITIONALLY READY.

## Instructions

### Phase 1: Stack Research (Gemini)

Before scanning code, research production best practices specific to this
project's tech stack. Read `project-context.md` to identify the stack and
determine the service criticality tier.

Load `/gemini` for invocation syntax. Key params: 120s timeout, prompt:
`"Research production readiness best practices for a [STACK] application.
Cover: deployment patterns (blue/green, canary, progressive delivery),
observability (SLI-based alerting, OpenTelemetry, cost-aware),
security hardening (supply chain, runtime security, network policies),
SLO/SLI definition, chaos engineering readiness, capacity planning,
incident response maturity, and common production antipatterns.
Be specific to this stack — not generic advice.
Project context: [first 3 sections of project-context.md]"`.
Replace `[STACK]` with the actual tech stack from project-context.md.
Output to `/tmp/prr-stack-research.md`.

If Gemini is unavailable or fails, retry with Copilot — load `/copilot`
for invocation syntax. Same prompt, same output file.
If both Gemini and Copilot fail, use Claude WebSearch. Stack research is NOT
optional — the production-specific checks in Phase 2 use these findings.

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

#### Track B: Production Antipattern Scan (5 Codex Workers)

Fan out 5 Codex instances — one per production dimension (Dims 8-12).
Uses all 5 available Codex slots.

Load `/codex` for invocation syntax. Key params for all 5 workers:
`--sandbox read-only`, `--ephemeral`, `--cd /path/to/project`, 120s timeout.

Read `references/production-scan-prompts.md` for prompts for Dims 8-10.
Read `references/reliability-capacity-prompts.md` for prompts for Dims 11-12.

Launch all 5 in parallel. Output each to `/tmp/prr-{dimension}.md`.

**Workers 1-3** — Observability (8), Deployment (9), Operations (10):
prompt from `references/production-scan-prompts.md`.

**Workers 4-5** — Reliability (11), Capacity (12):
prompt from `references/reliability-capacity-prompts.md`.

Wait for all 5 and store in DB:

```bash
source artifacts/db.sh
for dim in observability deployment operations reliability capacity; do
  wait $CODEX_PID
  db_upsert 'meta-production' 'scan' "$dim" "$(cat /tmp/prr-$dim.md)"
  rm /tmp/prr-$dim.md
done
```

If Codex is unavailable, run these 5 checks as Sonnet subagents instead.
Less depth but still covers the patterns via grep and file analysis.

#### Track C: Production Research Cross-Reference (Gemini)

While Track A and B run, have Gemini cross-reference the stack research
(Phase 1) against the project's actual implementation:

Load `/gemini` for invocation syntax. Key params: 120s timeout, prompt:
`"Compare these production best practices against the actual codebase.
For each practice, mark it as: IMPLEMENTED, PARTIALLY IMPLEMENTED, or MISSING.
Cite specific files and lines.
Best practices: $(cat /tmp/prr-stack-research.md)
Focus on the top 20 most critical practices for this stack."`.
Output to `/tmp/prr-practices.md`. Then store in DB:
```bash
source artifacts/db.sh
db_upsert 'meta-production' 'scan' 'practices-audit' "$(cat /tmp/prr-practices.md)"
rm /tmp/prr-practices.md
```

If Gemini is unavailable or fails, retry Track C with Copilot — load `/copilot`
for invocation syntax. Same prompt, same output file and DB storage step.
If both Gemini and Copilot fail, skip this track. It enriches the report but
isn't required for scoring.

### Phase 3: Scoring

After all Phase 2 scans complete, score each dimension. Read `references/scoring-rubric.md`
for the full scoring tables per dimension group.

**For Dimensions 1-7** — read lens findings from artifact DB:

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

**For Dimensions 8-10** — read production scan findings:

```bash
source artifacts/db.sh
OBSERVABILITY=$(db_read 'meta-production' 'scan' 'observability')
DEPLOYMENT=$(db_read 'meta-production' 'scan' 'deployment')
OPERATIONS=$(db_read 'meta-production' 'scan' 'operations')
PRACTICES=$(db_read 'meta-production' 'scan' 'practices-audit')
```

**For Dimensions 11-12** — criticality-weighted:

```bash
RELIABILITY=$(db_read 'meta-production' 'scan' 'reliability')
CAPACITY=$(db_read 'meta-production' 'scan' 'capacity')
```

Apply service criticality tier weighting per `references/scoring-rubric.md`.
Read `references/slo-chaos-dora-checks.md` for detailed tier criteria.

**Cross-validation**: Compare Codex findings against Gemini practices audit (Track C).
The more conservative score wins unless you can verify the optimistic assessment.

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
> 4. **Full review** — run `/meta-review` for the complete review sweep"

## Error Handling

- **Gemini unavailable**: Try Copilot for Phase 1 + Track C. If both fail, use WebSearch for Phase 1, skip Track C. Note in methodology.
- **Codex unavailable**: Run Dims 8-12 as Sonnet subagents. Note reduced depth in methodology.
- **Both unavailable**: All scans via Sonnet. Note "single-model assessment" in methodology, reduce Dims 8-12 confidence.
- **Lens failure**: Score that dimension 0, note "assessment incomplete" in scorecard.

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
