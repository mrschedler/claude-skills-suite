---
name: drift-review
description: "Compares code against project-context.md, features.md, and project-plan.md to find drift. Use when docs may be out of sync with reality, or after a long implementation sprint."
---

# Drift Review

## Purpose

Verify that documentation and code tell the same story. In LLM-assisted projects, drift
happens fast: features get added without updating features.md, architecture evolves
without updating project-context.md, and plan phases get reordered without updating
project-plan.md. This skill performs a systematic comparison between documented intent
and implemented reality.

This is distinct from counter-review (which challenges whether the plan is good) and
refactor-review (which challenges how the code is written). Drift review only asks:
does the code match what the docs say?

## Inputs

- The full codebase
- `project-context.md` — stated architecture, scope, and design decisions
- `features.md` — feature list with status tracking
- `project-plan.md` — implementation phases and deliverables

## Outputs

- **Standalone mode**: Store findings in the artifact DB:
  ```bash
  source artifacts/db.sh
  db_upsert 'drift-review' 'findings' 'standalone' "$FINDINGS_CONTENT"
  ```
- **Multi-model mode** (called by meta-review): Store per-model findings in the artifact DB:
  - Sonnet: `db_upsert 'drift-review' 'findings' 'sonnet' "$CONTENT"`
  - Codex: `db_upsert 'drift-review' 'findings' 'codex' "$CONTENT"`
  - Gemini: `db_upsert 'drift-review' 'findings' 'gemini' "$CONTENT"`

## Instructions

### Fresh Findings Check

Before running a new scan, check if fresh findings already exist:
```bash
source artifacts/db.sh
AGE=$(db_age_hours 'drift-review' 'findings' 'standalone')
# For multi-model: db_age_hours 'drift-review' 'findings' 'sonnet'
```
If `$AGE` is non-empty and less than 24, report: "Found fresh drift-review findings from $AGE hours ago. Reuse them? (y/n)"
If the user says yes, read findings from DB: `db_read 'drift-review' 'findings' 'standalone'` (or `sonnet`/`codex`/`gemini` as appropriate).
If no record exists or user says no, proceed with a fresh scan.

### 1. Extract Documented Claims

Read all three input documents and extract concrete, verifiable claims:

From `project-context.md`:
- Technology stack (languages, frameworks, databases)
- Architecture pattern (monolith, microservices, serverless, etc.)
- Module/component structure
- Integration points (APIs, services, databases)
- Stated constraints and non-goals

From `features.md`:
- Each feature and its documented status (planned, in-progress, done)
- Feature descriptions and acceptance criteria

From `project-plan.md`:
- Phase deliverables and their stated completion status
- Dependencies between phases
- Deferred/cut items

Build a checklist of these claims. Each one gets verified against the code.

### 2. Code-to-Docs Comparison (What's documented but missing)

For each documented claim, search the codebase for evidence:
- Features marked "done" — find the implementing code. If it doesn't exist or is a stub,
  that's drift.
- Architecture claims — verify the actual structure matches. If project-context.md says
  "REST API with Express" but the code uses Fastify, that's drift.
- Stack claims — check actual dependencies against what's documented.
- Integration claims — verify the integration code exists and connects to the stated services.

Flag every discrepancy with the specific doc reference and code location (or absence).

### 3. Docs-to-Code Comparison (What's built but undocumented)

Scan the codebase for functionality that doesn't appear in any doc:
- Routes/endpoints not mentioned in features.md
- Modules/services not mentioned in project-context.md
- Dependencies not mentioned in the stack description
- Features that work but aren't listed anywhere

Undocumented features are drift too — they mean the docs can't be trusted as a complete
picture of the system.

### Code-Side Discovery (Codex)

After comparing docs to code, run a reverse check — find things in code that docs don't mention:

1. Check Codex availability: `which codex >/dev/null 2>&1`
2. If available:
   ```bash
   CODEX=$(ls ~/.nvm/versions/node/*/bin/codex 2>/dev/null | sort -V | tail -1)
   test -x "$CODEX" || CODEX="/opt/homebrew/bin/codex"
   GTIMEOUT="/opt/homebrew/bin/gtimeout"; test -x "$GTIMEOUT" || GTIMEOUT="/opt/homebrew/bin/timeout"
   $GTIMEOUT 60 "$CODEX" exec --ephemeral --sandbox read-only --skip-git-repo-check \
     --cd <project-root> \
     "Scan this codebase for features, endpoints, configuration options, and behaviors that are NOT documented in any .md file in the project root. List each with file:line. Focus on: API endpoints without docs, env vars without .env.example entries, CLI flags without README mention, and database tables without schema docs."
   ```
3. Add any undocumented findings to the drift report as "Code-ahead" items.
4. If Codex is unavailable, skip this step — the standard doc-to-code comparison still runs.

### 4. Status Accuracy Check

Focus specifically on the status fields in features.md and project-plan.md:
- Features marked "done" — are they actually complete? (Test by tracing the feature
  end-to-end through the code.)
- Features marked "in-progress" — is there any code for them, or did they stall?
- Features marked "planned" — is there already code for them? (Status should be updated.)
- Plan phases marked complete — are all deliverables actually present?

### 5. Produce Findings

Write findings to the output file with this structure per finding:

```
## [SEVERITY] Finding Title

**Drift Direction**: Docs ahead of code | Code ahead of docs | Contradiction
**Doc Reference**: Which document, which section, exact quote
**Code Reference**: file/path:line (or "no corresponding code found")

**What the docs say**: Quote the relevant documentation.

**What the code does**: Describe the actual behavior or show a code snippet.

**Resolution**: Which is correct — the doc or the code? Recommend updating whichever
is wrong. If unclear, flag for human decision.
```

Drift directions:
- **Docs ahead of code** — Documentation describes something that isn't built yet
  (features marked done but not implemented)
- **Code ahead of docs** — Code exists for something not documented
  (undocumented features, architecture changes)
- **Contradiction** — Both exist but disagree (docs say X, code does Y)

Severity levels:
- **CRITICAL** — Feature marked "done" that doesn't work, or architectural contradiction
  that would mislead a new developer
- **HIGH** — Significant undocumented functionality or incorrect status tracking
- **MEDIUM** — Minor discrepancy that could cause confusion
- **LOW** — Cosmetic doc issue (naming inconsistency, outdated terminology)

### 6. Summarize

End with:
- A drift map table: document | section | drift direction | severity
- Count of findings by direction and severity
- Overall sync assessment: are the docs trustworthy, or do they need a major update pass?
- Recommendation: which documents should be updated first to restore trust

## Execution Mode

- **Standalone**: Spawn the `review-lens` agent (`subagent_type: "review-lens"`) with this skill's lens instructions and input files. Stores findings in DB as `db_upsert 'drift-review' 'findings' 'standalone'`.
- **Via meta-review**: The `review-lens` agent runs the Sonnet review, while Codex (`/codex`) and Gemini (`/gemini`) run in parallel with the same prompt. Each model stores findings in DB under label `sonnet`, `codex`, or `gemini`. The meta-review skill handles synthesis.

## Examples

```
User: Do our docs match what's actually built?
→ Triggers drift-review. Full comparison of all three input documents against the codebase.
```

```
User: I need to update features.md. What's actually done vs what it says?
→ Triggers drift-review with emphasis on the Status Accuracy Check section.
```

```
User: A new developer is joining. Can they trust our project docs?
→ Triggers drift-review. Frame findings as "here's what would mislead the new developer."
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
