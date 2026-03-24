---
name: drift-review
description: "Compares code against project documentation to find drift. Use when docs may be out of sync with reality, or after a long implementation sprint."
---

# Drift Review

## Purpose

Verify that documentation and code tell the same story. In AI-assisted projects,
drift happens fast: features get added without updating docs, architecture evolves
without updating GROUNDING.md, and plan phases get reordered silently. This skill
performs a systematic comparison between documented intent and implemented reality.

## Inputs

- The full codebase
- GROUNDING.md — stated architecture, scope, decisions, constraints
- Any other project docs: project-context.md, project-plan.md, feature lists, README

## Outputs

See `references/review-lens-framework.md` for the shared output pattern.

## Instructions

### Fresh Findings Check

See `references/review-lens-framework.md`.

### 1. Extract Documented Claims

Read all project documentation and extract concrete, verifiable claims:

**From GROUNDING.md / project-context.md:**
- Technology stack (languages, frameworks, databases)
- Architecture pattern
- Module/component structure
- Integration points
- Stated constraints and non-goals
- Key decisions and their rationale

**From feature lists / project plans (if they exist):**
- Each feature and its documented status
- Phase deliverables and completion status
- Deferred/cut items

Build a checklist of claims. Each one gets verified against the code.

### 2. Code-to-Docs Comparison (What's documented but missing)

For each documented claim, search the codebase for evidence:
- Features described as "done" — find implementing code. If absent or stubbed, that's drift.
- Architecture claims — verify actual structure matches
- Stack claims — check actual dependencies vs documented
- Integration claims — verify integration code exists

Flag every discrepancy with the specific doc reference and code location (or absence).

### 3. Docs-to-Code Comparison (What's built but undocumented)

Scan the codebase for functionality not in any doc:
- Routes/endpoints not mentioned in docs
- Modules/services not in architecture description
- Dependencies not in the stack description
- Features that work but aren't listed

Undocumented features are drift too — they mean docs can't be trusted as a complete picture.

### 4. Status Accuracy Check

Focus on status fields in any feature list or plan:
- "Done" features — actually complete? (Trace end-to-end)
- "In-progress" features — is there code, or did they stall?
- "Planned" features — code already exists? (Status should be updated)

### 5. Produce Findings

```
## [SEVERITY] Finding Title

**Drift Direction**: Docs ahead of code | Code ahead of docs | Contradiction
**Doc Reference**: Which document, which section, exact quote
**Code Reference**: file/path:line (or "no corresponding code found")

**What the docs say**: Quote the documentation.
**What the code does**: Describe actual behavior or show snippet.
**Resolution**: Which is correct? Recommend updating whichever is wrong.
```

Drift directions:
- **Docs ahead of code** — docs describe something not built
- **Code ahead of docs** — code exists for something undocumented
- **Contradiction** — both exist but disagree

Severity:
- **CRITICAL** — Feature marked "done" that doesn't work, or architectural contradiction
- **HIGH** — Significant undocumented functionality or incorrect status
- **MEDIUM** — Minor discrepancy causing confusion
- **LOW** — Naming inconsistency, outdated terminology

### 6. Summarize

- Drift map table: document | section | drift direction | severity
- Count by direction and severity
- Overall sync assessment: are the docs trustworthy?
- Recommendation: which documents to update first

## Examples

```
User: Do our docs match what's actually built?
→ Full comparison of all project docs against codebase.
```

```
User: A new developer is joining. Can they trust our docs?
→ Frame findings as "what would mislead the new developer."
```

---

Before completing, read and follow `../references/review-lens-framework.md` and `../references/cross-cutting-rules.md`.
