---
name: counter-review
description: Adversarial red-team review. Attacks architecture, completeness, drift, over-engineering, abuse cases, attack chains, and failure scenarios. Cross-references code against docs.
---

# Counter-Review

## Purpose

Act as a hostile reviewer AND a creative attacker. This skill goes beyond finding
problems — it constructs exploit paths, abuse scenarios, and failure chains. Where
security-review checks known patterns against checklists, counter-review asks
"how would I break this?" and builds the proof.

LLM-assisted development creates a blind spot: the same model that wrote the code
will think the code is fine. Counter-review breaks that loop by attacking from
7 angles, including 3 adversarial vectors that security-review does not cover.

## Boundary with Security-Review

| Concern | security-review | counter-review |
|---|---|---|
| Known vuln patterns (SQLi, XSS, etc.) | YES — checklist-driven | No — defers to security-review |
| OWASP / CWE compliance | YES — P0/P1/P2 tiers | No |
| Architecture fitness | No | YES — is the design sound? |
| Business logic abuse | No | YES — how would a malicious user exploit this? |
| Attack chain construction | No | YES — chain low findings into high exploits |
| Failure scenario stress testing | No | YES — what if assumptions fail? |
| Completeness / drift from docs | Partial (IaC only) | YES — full doc cross-reference |

## Inputs

- `project-context.md` — the project's stated purpose, scope, and constraints
- `features.md` — the feature list with status tracking
- `project-plan.md` — the implementation plan and phase breakdown
- The full codebase

## Outputs

See `references/review-lens-framework.md` for the shared output pattern.
Lens name for DB operations: `counter-review`

## Instructions

### Fresh Findings Check

See `references/review-lens-framework.md`. Lens: `counter-review`.

### 1. Load Context

Read `project-context.md`, `features.md`, and `project-plan.md` from the project root.
These are the "contract" the codebase is supposed to fulfill. Every finding should
reference which part of the contract is violated or at risk.

Also determine:
- Is this a web app, CLI, library, or agent system?
- Is it user-facing or internal?
- Does it handle money, PII, or credentials?
- Does it involve AI agents or tool-calling LLMs?

This shapes which attack vectors matter most. A CLI tool needs less abuse-case
analysis than a public web API.

### 2. Architecture Attack

Challenge the overall architecture:
- Is the chosen stack justified, or was it cargo-culted from a template?
- Are there unnecessary layers of abstraction (over-engineering)?
- Are there missing layers where complexity is crammed into one file (under-engineering)?
- Does the dependency graph make sense, or are there circular imports / god modules?
- Would this architecture survive 10x the current scale? Does it need to?

### 3. Completeness Attack

Scan for signs of unfinished work:
- Stubs, TODOs, placeholder values, empty catch blocks
- Functions that exist in the interface but have no real implementation
- Features listed in `features.md` that have no corresponding code
- Code paths that silently swallow errors

### 4. Drift Attack

Compare what the docs say vs what the code does:
- Features marked "done" in `features.md` that are actually incomplete
- Architectural decisions in `project-context.md` that the code contradicts
- Plan phases in `project-plan.md` that were skipped or half-implemented

### 5. Over-Engineering Attack

Look for complexity that doesn't earn its keep:
- Abstractions with only one implementation
- Config systems more complex than the thing they configure
- Premature optimization (caching, pooling, lazy loading) with no profiling evidence
- Generic frameworks built for a specific use case

### 6. Adversarial Abuse Cases

Read `references/abuse-cases.md` for the full catalog.

Think like a malicious user. For each user-facing feature, ask:
- **Business logic**: Can prices/quantities/roles be manipulated via the API?
- **Input boundaries**: What happens with oversized payloads, unicode tricks, or encoding attacks?
- **State manipulation**: Are there race conditions, replay attacks, or TOCTOU gaps?
- **Workflow abuse**: Can required steps be skipped by hitting the API directly?

If the project involves AI agents:
- **Prompt injection**: Can user input reach agent context and override instructions?
- **Tool abuse**: Can an attacker influence which tools the agent calls or with what parameters?
- **Context poisoning**: Can adversarial content be planted in data the agent reads later?

Focus on abuse scenarios that security-review would NOT catch — business logic flaws,
workflow bypasses, and creative misuse of intended features.

### 7. Attack Chain Construction

Read `references/attack-chains.md` for the methodology and templates.

This is counter-review's unique capability. Chain individual findings (from this
review AND from other lenses if available) into multi-step exploit paths:

1. **Map trust boundaries** — where does user input cross into trusted context?
2. **Identify escalation paths** — unauthenticated → authenticated → admin → system
3. **Trace data exfiltration routes** — what sensitive data can be reached and how?
4. **Build chains** — combine 2-3 low/medium findings into a high/critical path

Each chain is a separate finding with the full path documented. A chain of three
LOW findings that leads to a CRITICAL outcome is itself a CRITICAL finding.

### 8. "What If" Scenarios

Read `references/what-if-scenarios.md` for the full scenario catalog.

Stress test the project's assumptions:
- **Infrastructure**: What if the DB goes down? What if traffic spikes 100x?
- **Security breach**: What if an API key leaks? What if a dependency is compromised?
- **Scale**: What if the data grows 10x? What if 1000 concurrent users hit the same endpoint?
- **Operational**: What if a deploy fails midway? What if you need to restore from backup?

For each relevant scenario, assess: HANDLED, PARTIALLY HANDLED, or UNHANDLED.
Focus on scenarios that are realistic for this project's scale and deployment.
Don't flag "what if 1M users" for an internal tool with 5 users.

### 9. Produce Findings

Format each finding using this structure (store via `db_upsert` as shown in Outputs above):

```
## [SEVERITY] Finding Title

**Category**: Architecture | Completeness | Drift | Over-Engineering | Abuse Case | Attack Chain | Scenario
**Location**: file/path:line (or module name)
**Contract Reference**: Which doc + section this relates to

**Problem**: What's wrong, specifically.

**Evidence**: Code snippet or doc quote showing the issue.

**Recommendation**: What to do about it. Be specific — "refactor this" is not helpful.
```

For **Attack Chain** findings, use this extended format:
```
## [SEVERITY] Chain: [Title]

**Category**: Attack Chain
**Entry Point**: How the attacker gets in
**Path**:
  1. [SEVERITY] First finding (file:line) — what it enables
  2. [SEVERITY] Second finding (file:line) — what it enables
  3. [SEVERITY] Final impact — what the attacker achieves

**Prerequisites**: What the attacker needs
**Likelihood**: HIGH (automated) | MEDIUM (targeted) | LOW (insider/luck)
**Impact**: What data/systems are compromised

**Mitigation**: Breaking the weakest link (cheapest fix)
```

For **Scenario** findings, use this format:
```
## [SEVERITY] What if [scenario]?

**Category**: Scenario
**Assumption Challenged**: What the project currently assumes
**Current Behavior**: What actually happens (tested or inferred)
**Risk**: What goes wrong
**Verdict**: HANDLED | PARTIALLY HANDLED | UNHANDLED

**Mitigation**: What should be in place
```

Severity levels:
- **CRITICAL** — Blocks deployment or causes data loss / security exposure
- **HIGH** — Significant functionality gap or architectural flaw
- **MEDIUM** — Quality issue that should be fixed before next milestone
- **LOW** — Nitpick or suggestion for improvement

### 10. Summarize

End findings with a summary table: count of findings by severity and category.
Include:
- Attack chains constructed (count and highest severity)
- Scenarios assessed (count by verdict: HANDLED / PARTIALLY / UNHANDLED)
- One-paragraph overall assessment: is this project in good shape, or does it
  need significant rework?

## References (on-demand)

Read these files only when needed for the relevant section:
- `references/abuse-cases.md` — Business logic abuse, input boundary exploitation, agentic app abuse catalog
- `references/attack-chains.md` — Trust boundary mapping, escalation path templates, chain construction methodology, severity scoring
- `references/what-if-scenarios.md` — Infrastructure failure, security breach, scale, and operational scenario catalogs

## Execution Mode

See `references/review-lens-framework.md`. Lens: `counter-review`.

## Examples

```
User: Red team this project before I demo it tomorrow.
→ Full attack from all 7 angles. Emphasis on abuse cases and attack chains.
  Produce findings with chain documentation.
```

```
User: Something feels off about the architecture but I can't put my finger on it.
→ Emphasis on Architecture Attack (§2) and Over-Engineering Attack (§5).
```

```
User: We just finished phase 2. Sanity check everything.
→ Cross-reference project-plan.md phase 2 deliverables against actual code.
  Flag anything missing or half-done. Run "what if" scenarios on new features.
```

```
User: We're about to go live. What could go wrong?
→ Heavy emphasis on Abuse Cases (§6), Attack Chains (§7), and Scenarios (§8).
  Build chains from any existing security-review findings. Stress test deployment
  and failure recovery assumptions.
```

```
User: An AI agent handles user requests in this app. Poke holes in it.
→ Emphasis on Agentic Abuse Cases in §6. Read references/abuse-cases.md → Agentic
  App Abuse section. Test prompt injection, tool abuse, and context poisoning vectors.
```

---

Before completing, read and follow `../references/review-lens-framework.md` and `../references/cross-cutting-rules.md`.
