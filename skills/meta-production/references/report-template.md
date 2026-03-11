# Production Readiness Report Template

Write `artifacts/reviews/production-readiness.md` following this structure exactly.

---

```markdown
# Production Readiness Report

> Project: {{PROJECT_NAME}}
> Date: {{DATE}}
> Assessed by: Claude (Opus) + Codex + Gemini
> Stack: {{TECH_STACK}}

## Verdict: {{VERDICT}}

**Total Score: {{SCORE}}/100**

{{If CONDITIONALLY READY or NOT READY: list the specific conditions or
blockers that must be resolved}}

## Scorecard

| # | Dimension | Score | Grade | Key Findings |
|---|---|---|---|---|
| 1 | Code Completeness | X/10 | A/B/C/D/F | One-line summary |
| 2 | Code Quality | X/10 | A/B/C/D/F | One-line summary |
| 3 | Security | X/10 | A/B/C/D/F | One-line summary |
| 4 | Testing | X/10 | A/B/C/D/F | One-line summary |
| 5 | Documentation Sync | X/10 | A/B/C/D/F | One-line summary |
| 6 | Compliance | X/10 | A/B/C/D/F | One-line summary |
| 7 | Architecture | X/10 | A/B/C/D/F | One-line summary |
| 8 | Observability | X/10 | A/B/C/D/F | One-line summary |
| 9 | Deployment | X/10 | A/B/C/D/F | One-line summary |
| 10 | Operations | X/10 | A/B/C/D/F | One-line summary |

Grade scale: A (9-10), B (7-8), C (5-6), D (3-4), F (0-2)

## Critical Blockers

{{List any CRITICAL severity findings that must be resolved before
production. If none, state "No critical blockers identified."}}

## Dimension Details

### 1. Code Completeness (X/10)

**What was checked**: [brief description]
**Findings**: [top findings with file:line citations]
**What's done well**: [positive observations]

[Repeat for all 10 dimensions]

## Production Patterns Implemented

{{List production-positive patterns found in the codebase — graceful
shutdown, health checks, structured logging, etc. This section recognizes
what's already done right.}}

## Remediation Plan

{{Ordered list of what to fix, grouped by priority:
- P0: Must fix before production (CRITICAL findings)
- P1: Should fix before production (HIGH findings in low-scoring dimensions)
- P2: Fix soon after launch (MEDIUM findings)
- P3: Address when convenient (LOW findings)}}

## Methodology

- **Review lenses**: 7 lenses via Sonnet subagents (review-lens agent)
- **Production scan**: Codex CLI read-only antipattern scan
- **Stack research**: Gemini CLI with Google Search grounding
- **Practices audit**: Gemini codebase_investigator cross-reference
- **Scoring**: Evidence-based rubric, cross-validated across models
- **Confidence**: Multi-model agreement scoring (findings flagged by
  multiple models weighted higher)

## Sources

- [Google SRE Production Readiness Review](https://sre.google/sre-book/evolving-sre-engagement-model/)
- [Google SRE Launch Checklist](https://sre.google/sre-book/launch-checklist/)
- [Cortex Production Readiness Scorecard](https://www.cortex.io/post/how-to-create-a-great-production-readiness-checklist)
- [DORA Metrics](https://dora.dev/guides/dora-metrics/)
```
