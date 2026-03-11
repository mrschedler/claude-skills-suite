---
name: counter-review
description: Red-teams the project at milestones or before deployment. Pokes holes in architecture, completeness, over-engineering, and gaps. Cross-references code against docs for drift.
---

# Counter-Review

## Purpose

Act as a hostile reviewer. Assume the codebase has problems and find them. This skill
exists because LLM-assisted development creates a blind spot: the same model that wrote
the code will think the code is fine. Counter-review breaks that loop by systematically
attacking the project from multiple angles.

## Inputs

- `project-context.md` — the project's stated purpose, scope, and constraints
- `features.md` — the feature list with status tracking
- `project-plan.md` — the implementation plan and phase breakdown
- The full codebase

## Outputs

- **Standalone mode**: Store findings in the artifact DB:
  ```bash
  source artifacts/db.sh
  db_upsert 'counter-review' 'findings' 'standalone' "$FINDINGS_CONTENT"
  ```
- **Multi-model mode** (called by meta-review): Store per-model findings in the artifact DB:
  - Sonnet: `db_upsert 'counter-review' 'findings' 'sonnet' "$CONTENT"`
  - Codex: `db_upsert 'counter-review' 'findings' 'codex' "$CONTENT"`
  - Gemini: `db_upsert 'counter-review' 'findings' 'gemini' "$CONTENT"`

## Instructions

### Fresh Findings Check

Before running a new scan, check if fresh findings already exist:
```bash
source artifacts/db.sh
AGE=$(db_age_hours 'counter-review' 'findings' 'standalone')
# For multi-model: db_age_hours 'counter-review' 'findings' 'sonnet'
```
If `$AGE` is non-empty and less than 24, report: "Found fresh counter-review findings from $AGE hours ago. Reuse them? (y/n)"
If the user says yes, read findings from DB: `db_read 'counter-review' 'findings' 'standalone'` (or `sonnet`/`codex`/`gemini` as appropriate).
If no record exists or user says no, proceed with a fresh scan.

### 1. Load Context

Read `project-context.md`, `features.md`, and `project-plan.md` from the project root.
These are the "contract" the codebase is supposed to fulfill. Every finding should
reference which part of the contract is violated or at risk.

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

### 6. Produce Findings

Write findings to the output file with this structure per finding:

```
## [SEVERITY] Finding Title

**Category**: Architecture | Completeness | Drift | Over-Engineering
**Location**: file/path:line (or module name)
**Contract Reference**: Which doc + section this relates to

**Problem**: What's wrong, specifically.

**Evidence**: Code snippet or doc quote showing the issue.

**Recommendation**: What to do about it. Be specific — "refactor this" is not helpful.
```

Severity levels:
- **CRITICAL** — Blocks deployment or causes data loss / security exposure
- **HIGH** — Significant functionality gap or architectural flaw
- **MEDIUM** — Quality issue that should be fixed before next milestone
- **LOW** — Nitpick or suggestion for improvement

### 7. Summarize

End the findings file with a summary table: count of findings by severity and category.
Include a one-paragraph overall assessment: is this project in good shape, or does it
need significant rework?

## Execution Mode

- **Standalone**: Spawn the `review-lens` agent (`subagent_type: "review-lens"`) with this skill's lens instructions and input files. Stores findings in DB as `db_upsert 'counter-review' 'findings' 'standalone'`.
- **Via meta-review**: The `review-lens` agent runs the Sonnet review, while Codex (`/codex`) and Gemini (`/gemini`) run in parallel with the same prompt. Each model stores findings in DB under label `sonnet`, `codex`, or `gemini`. The meta-review skill handles synthesis.

## Examples

```
User: Red team this project before I demo it tomorrow.
→ Triggers counter-review. Load all context docs, attack from all angles, produce findings.
```

```
User: Something feels off about the architecture but I can't put my finger on it.
→ Triggers counter-review with emphasis on the Architecture Attack phase.
```

```
User: We just finished phase 2. Sanity check everything.
→ Triggers counter-review. Cross-reference project-plan.md phase 2 deliverables against
  actual code. Flag anything missing or half-done.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
