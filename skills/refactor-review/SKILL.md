---
name: refactor-review
description: Code quality and efficiency pass. Catches over-engineering, duplication, bloat, truncated code, and unnecessary abstractions. Use before any major refactor or cleanup.
---

# Refactor Review

## Purpose

Find code that should be simpler. LLM-generated codebases develop a specific pathology:
each prompt produces reasonable code in isolation, but the accumulated result has
duplicated utilities, inconsistent patterns, over-abstracted layers, and truncated
blocks where a previous generation was cut short. This skill identifies concrete
refactoring opportunities and flags drift from the project's stated architecture.

## Inputs

- The full codebase
- `project-context.md` — stated architecture, patterns, and constraints
- `features.md` — what features exist and their status

## Outputs

- **Standalone mode**: Store findings in the artifact DB:
  ```bash
  source artifacts/db.sh
  db_upsert 'refactor-review' 'findings' 'standalone' "$FINDINGS_CONTENT"
  ```
- **Multi-model mode** (called by meta-review): Store per-model findings in the artifact DB:
  - Sonnet: `db_upsert 'refactor-review' 'findings' 'sonnet' "$CONTENT"`
  - Codex: `db_upsert 'refactor-review' 'findings' 'codex' "$CONTENT"`
  - Gemini: `db_upsert 'refactor-review' 'findings' 'gemini' "$CONTENT"`

## Instructions

### Fresh Findings Check

Before running a new scan, check if fresh findings already exist:
```bash
source artifacts/db.sh
AGE=$(db_age_hours 'refactor-review' 'findings' 'standalone')
# For multi-model: db_age_hours 'refactor-review' 'findings' 'sonnet'
```
If `$AGE` is non-empty and less than 24, report: "Found fresh refactor-review findings from $AGE hours ago. Reuse them? (y/n)"
If the user says yes, read findings from DB: `db_read 'refactor-review' 'findings' 'standalone'` (or `sonnet`/`codex`/`gemini` as appropriate).
If no record exists or user says no, proceed with a fresh scan.

### 1. Load Context

Read `project-context.md` and `features.md`. Understand:
- What patterns and conventions does the project claim to follow?
- What's the intended module structure?
- What scale is this built for? (Over-engineering for a small tool is different than
  under-engineering for a platform.)

### 2. Duplication Scan

Find code that's repeated instead of shared:
- Near-identical functions in different files (same logic, different names)
- Copy-pasted blocks with minor variations (should be parameterized)
- Multiple implementations of the same utility (string formatting, date parsing, error handling)
- Repeated boilerplate that should be abstracted (API call patterns, DB queries)

For each instance, estimate the deduplication savings (lines removed, files simplified).

### 3. Over-Engineering Detection

Flag unnecessary complexity:
- Abstractions with only one implementation (interfaces/abstract classes used once)
- Factory patterns for creating a single type
- Plugin systems with no plugins
- Config systems more complex than the features they configure
- Generic frameworks built for a specific use case
- Multiple layers of indirection that add no value (wrapper functions that just forward args)
- Event systems or pub/sub patterns used for simple direct calls

The test: if removing the abstraction and inlining the code makes it easier to understand
with no loss of functionality, it's over-engineered.

### 4. Truncation and Incomplete Code

LLM-specific pattern: code that was generated in a previous session but truncated
mid-function, then a new session continued without completing the original. Look for:
- Functions that start complex logic but return early with a simplified path
- Comment blocks like `// ... rest of implementation` or `// TODO: complete this`
- Error handlers that catch but don't handle (empty catch blocks)
- Switch/match statements missing obvious cases
- Functions whose name promises more than the body delivers

### 5. Consistency Audit

Check for pattern inconsistency across the codebase:
- Mixed async patterns (callbacks + promises + async/await in the same project)
- Inconsistent error handling (some functions throw, some return null, some return Result)
- Mixed naming conventions (camelCase and snake_case in the same language)
- Inconsistent file organization (some features in one file, others split across many)
- Multiple ways of doing the same thing (fetch + axios, moment + dayjs)

### 6. Drift Check

Compare the code's actual structure against `project-context.md`:
- Does the module structure match what's documented?
- Are the stated patterns actually followed consistently?
- Have new patterns emerged in the code that aren't documented?
- Are there modules or features that don't appear in any project doc?

### 7. Produce Findings

Write findings to the output file with this structure per finding:

```
## [SEVERITY] Finding Title

**Category**: Duplication | Over-Engineering | Truncation | Inconsistency | Drift
**Location**: file/path:line (list all affected files for duplication findings)
**Impact**: Lines of code affected, complexity reduction potential

**Problem**: What's wrong, specifically.

**Evidence**: Code snippets showing the issue. For duplication, show both copies side by side.

**Recommendation**: Specific refactoring steps. Name the target function/module/pattern.
Include a brief sketch of the simplified version where helpful.
```

Severity levels:
- **CRITICAL** — Truncated/incomplete code that will fail at runtime
- **HIGH** — Significant duplication or over-engineering that impedes maintainability
- **MEDIUM** — Inconsistency or mild over-engineering that causes confusion
- **LOW** — Style or organization improvement

### 8. Summarize

End with:
- Count of findings by severity and category
- Estimated total lines of code that could be removed through deduplication
- Top 3 highest-impact refactors (the ones that would simplify the most code)
- Overall assessment: is this codebase clean, or does it need a cleanup pass?

## Execution Mode

- **Standalone**: Spawn the `review-lens` agent (`subagent_type: "review-lens"`) with this skill's lens instructions and input files. Stores findings in DB as `db_upsert 'refactor-review' 'findings' 'standalone'`.
- **Via meta-review**: The `review-lens` agent runs the Sonnet review, while Codex (`/codex`) and Gemini (`/gemini`) run in parallel with the same prompt. Each model stores findings in DB under label `sonnet`, `codex`, or `gemini`. The meta-review skill handles synthesis.

## Examples

```
User: This codebase feels bloated. Find what can be simplified.
→ Triggers refactor-review. Full scan with emphasis on duplication and over-engineering.
```

```
User: We've been building for 3 weeks with AI. Is there accumulated cruft?
→ Triggers refactor-review. Emphasis on truncation detection and consistency audit,
  since multi-session AI work accumulates these specific problems.
```

```
User: Before I refactor the API layer, tell me what else needs cleanup too.
→ Triggers refactor-review. Produce a prioritized list so the user can batch refactors.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
