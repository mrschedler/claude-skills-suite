# Scoring Rubric — Production Readiness Review

## Service Criticality Tier

Before scoring, determine the service's criticality tier from project-context.md:

| Tier | Description | Dims 11-12 Weight | Example |
|---|---|---|---|
| **Critical** | User-facing, revenue-impacting, or safety-critical | Full weight | Payment API, auth service |
| **Standard** | Internal service with dependencies downstream | 70% weight | Data pipeline, admin API |
| **Low** | Internal tool, batch job, or early-stage prototype | 40% weight | CLI tool, cron job, dev utility |

Criticality affects scoring for Dims 11 (Reliability) and 12 (Capacity) only.
A batch job doesn't need SLOs or load tests — don't penalize it for that.
Dims 1-10 apply equally regardless of tier.

## 12 Dimensions (0-10 each, 120 total)

| # | Dimension | What It Measures | Primary Source |
|---|---|---|---|
| 1 | **Code Completeness** | No stubs, TODOs, placeholders, incomplete implementations | completeness-review |
| 2 | **Code Quality** | No duplication, consistent patterns, no over-engineering, no truncation | refactor-review |
| 3 | **Security** | No secrets, deps audited, auth solid, input validated, OWASP + supply chain | security-review |
| 4 | **Testing** | Coverage adequate, no stub tests, error paths tested, mutation-aware | test-review |
| 5 | **Documentation Sync** | Docs match code, no drift in either direction | drift-review |
| 6 | **Compliance** | Follows documented rules + applicable regulatory controls | compliance-review |
| 7 | **Architecture** | Stack justified, no circular deps, scaling considered, resilient | counter-review |
| 8 | **Observability** | Logging, metrics, tracing, SLI-based alerting, cost-aware, correlation IDs | Production scan |
| 9 | **Deployment** | Progressive delivery, rollback, env config, graceful shutdown, supply chain | Production scan |
| 10 | **Operations** | Incident maturity, on-call health, rate limiting, circuit breakers, DORA infra | Production scan |
| 11 | **Reliability** | SLO/SLI defined, error budgets, chaos readiness, resilience tested | Production scan |
| 12 | **Capacity** | Load test evidence, auto-scaling, capacity model, resource sizing | Production scan |

## Scoring Rubric Per Dimension

| Score | Meaning |
|---|---|
| 9-10 | Excellent — production-grade, no issues |
| 7-8 | Good — minor issues, none blocking |
| 5-6 | Acceptable — notable gaps but workable with known risks |
| 3-4 | Concerning — significant gaps that need addressing |
| 1-2 | Poor — critical issues, not safe for production |
| 0 | Missing — dimension not addressed at all |

## Verdict Thresholds

| Total Score | Verdict | Meaning |
|---|---|---|
| 102-120 (85%+) | **PRODUCTION READY** | Ship it. Minor items can be addressed post-launch. |
| 84-101 (70-84%) | **CONDITIONALLY READY** | Can ship if listed conditions are met first. |
| 60-83 (50-69%) | **NOT READY** | Significant work required. Remediation plan provided. |
| 0-59 (<50%) | **BLOCKED** | Critical failures. Do not deploy under any circumstances. |

**Override rule**: Any single dimension scoring 0-2 forces a maximum verdict
of CONDITIONALLY READY regardless of total score. A single critical gap can
sink a deployment.

## Scoring Criteria — Dimensions 1-7 (Review Lenses)

| Findings | Score |
|---|---|
| 0 CRITICAL, 0 HIGH | 9-10 |
| 0 CRITICAL, 1-2 HIGH | 7-8 |
| 0 CRITICAL, 3+ HIGH or 1 CRITICAL | 5-6 |
| 2+ CRITICAL or 5+ HIGH | 3-4 |
| 3+ CRITICAL | 1-2 |
| Lens not run / no data | 0 |

Adjust within the range based on MEDIUM/LOW count and finding severity.

## Scoring Criteria — Dimensions 8-10 (Production Scans)

| Findings | Score |
|---|---|
| Category fully addressed, patterns implemented | 9-10 |
| Most items addressed, 1-2 minor gaps | 7-8 |
| Some items addressed, notable gaps | 5-6 |
| Few items addressed, significant gaps | 3-4 |
| Category barely addressed | 1-2 |
| No evidence of any production consideration | 0 |

## Scoring Criteria — Dimensions 11-12 (Reliability + Capacity)

Apply service criticality tier weighting. See `slo-chaos-dora-checks.md` for
detailed scoring criteria per tier. Chaos readiness scores as a maturity
indicator — higher is better, but absence doesn't block.
