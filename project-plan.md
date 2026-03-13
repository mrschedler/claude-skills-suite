# Project Plan — Skill Suite Enhancement (perf-review, test-gen, dep-audit)

Generated: 2026-03-12
Based on: gap analysis of existing 45-skill suite

## Executive Summary

Adding three skills to close the biggest gaps in the review and generation pipeline:
`perf-review` (performance review lens), `test-gen` (test generation from review findings),
and `dep-audit` (dependency health audit lens). Two phases: parallel skill creation, then
validation and meta-review wiring. 8 work units, 6 parallelizable. ~1,300 LOC across
9 new files + 1 edit.

## Phases and Milestones

| Phase | Milestone | Target |
|---|---|---|
| Phase 1: Skill Creation | All 3 SKILL.md files + reference files + agent prompt written | Session 1 |
| Phase 2: Validation & Integration | All skills pass validation checklist; perf-review and dep-audit wired into meta-review | Session 1 |

## Technical Approach

### perf-review (Review Lens)
Performance review lens covering 9 categories: query performance, memory/allocation,
algorithmic complexity, caching, frontend rendering, payload/serialization, concurrency,
I/O patterns, and database analysis (including EXPLAIN plans and index coverage).
Follows the security-review pattern: fresh-findings check, numbered instruction phases,
finding format with severity, execution mode (standalone + multi-model), artifact DB output.
Frontend checks are conditional on project type (same pattern as ui-review in meta-review).

### test-gen (Action Skill)
Reads test-review findings from the artifact DB, prioritizes by severity, generates tests
via Sonnet subagents (same dispatch pattern as review lenses), runs them, and reports
results. Codex available as optional generation path. Worker prompt references
test-review's `llm-test-antipatterns.md` to avoid generating the exact anti-patterns
that test-review catches.

### dep-audit (Review Lens)
Dependency health audit with a Tool Discovery phase that auto-detects, installs (via
npx/pipx, never sudo), and runs ecosystem-specific audit CLIs. Combines live audit
output with static manifest analysis. Scoped to health/maintainability — not attack
vectors (that's security-review §3).

## Work Units

| ID | Title | Deps | Parallel | LOC | Key Files |
|---|---|---|---|---|---|
| WU-1-01 | perf-review SKILL.md | — | yes | 250 | skills/perf-review/SKILL.md |
| WU-1-02 | perf-review references | — | yes | 300 | skills/perf-review/references/perf-patterns.md, skills/perf-review/references/frontend-perf.md |
| WU-1-03 | test-gen SKILL.md | — | yes | 180 | skills/test-gen/SKILL.md |
| WU-1-04 | test-gen agent prompt | — | yes | 80 | skills/test-gen/agents/test-worker.md |
| WU-1-05 | dep-audit SKILL.md | — | yes | 220 | skills/dep-audit/SKILL.md |
| WU-1-06 | dep-audit references | — | yes | 250 | skills/dep-audit/references/audit-checks.md, skills/dep-audit/references/license-matrix.md |
| WU-2-01 | Validate all skills | WU-1-* | no | 0 | All SKILL.md files |
| WU-2-02 | Wire into meta-review | WU-2-01 | no | 30 | skills/meta-review/SKILL.md |

## Dependency Graph

```
WU-1-01 ──┐
WU-1-02 ──┤
WU-1-03 ──┼──→ WU-2-01 ──→ WU-2-02
WU-1-04 ──┤
WU-1-05 ──┤
WU-1-06 ──┘
```

Critical path: Any WU-1-xx → WU-2-01 → WU-2-02

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| dep-audit overlaps security-review §3 | High | Medium | Clear scope boundary in both skills. dep-audit = health. security-review = attacks. Cross-reference in both. |
| perf-review too generic without project context | Medium | Medium | Context-aware: reads project-context.md to detect stack and adjust which checks apply |
| test-gen produces low-quality tests | Medium | High | Worker prompt references llm-test-antipatterns.md. Generated tests must pass with meaningful assertions. Verify before presenting. |
| Meta-review gets heavy with 10 lenses | Low | Medium | perf-review and dep-audit can be opt-in flags in meta-review |

## Resolved Items

1. **test-gen dispatch**: Sonnet subagents (same pattern as review lenses). Codex as optional alternative.
2. **dep-audit runtime tools**: Agent auto-detects, installs (npx/pipx, no sudo), and runs audit CLIs per ecosystem.
3. **perf-review scope**: Exhaustive — includes DB query analysis (EXPLAIN plans, index coverage, connection pool sizing).
