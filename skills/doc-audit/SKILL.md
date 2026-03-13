---
name: doc-audit
description: Audits documentation quality, completeness, and accuracy. Catches stale READMEs, undocumented APIs, missing setup guides, and doc-code drift. Use before releases or quarterly.
---

# Doc Audit

Finds documentation gaps, stale content, and accuracy issues before they
confuse users or new contributors. Different from drift-review — drift-review
checks if project docs (project-context.md, features.md) match code. Doc-audit
checks if user-facing documentation (READMEs, API docs, setup guides,
inline docs) is complete, accurate, and useful.

This skill exists because documentation rots faster than code, and LLM-built
projects often have zero documentation beyond what was auto-generated.

## Inputs

- The full codebase
- `project-context.md` — to understand what the project does and who uses it
- `features.md` — to cross-reference documented vs actual features
- All markdown files in the repo
- API specs if present (OpenAPI, GraphQL schema)
- Inline documentation (JSDoc, docstrings, rustdoc, godoc)

## Outputs

- **Standalone mode**: Store findings in the artifact DB:
  ```bash
  source artifacts/db.sh
  db_upsert 'doc-audit' 'findings' 'standalone' "$FINDINGS_CONTENT"
  ```

## Instructions

### Fresh Findings Check

Before running a new scan, check if fresh findings already exist:
```bash
source artifacts/db.sh
AGE=$(db_age_hours 'doc-audit' 'findings' 'standalone')
```
If `$AGE` is non-empty and less than 24, report: "Found fresh doc-audit findings from $AGE hours ago. Reuse them? (y/n)"

### 1. Inventory Documentation

Catalog all documentation in the project:
- Root `README.md` — does it exist? When was it last updated?
- `CONTRIBUTING.md`, `CHANGELOG.md`, `LICENSE` — do they exist?
- `docs/` directory — what's in it?
- API documentation (generated or hand-written)
- Architecture diagrams or decision records (ADRs)
- Setup/installation guides
- Inline code documentation (JSDoc, docstrings, comments)
- Configuration documentation (env vars, config files)

Report what exists and what's missing for the project's type and audience.

### 2. README Quality (CRITICAL/HIGH)

Evaluate the root README:
- **Exists at all** — missing README is CRITICAL for any public or shared project
- **What it does** — is the project's purpose clear in the first paragraph?
- **How to install/setup** — are prerequisites, install steps, and initial config documented?
- **How to use** — are there usage examples? Do they work?
- **How to contribute** — is there a contribution path for non-trivial projects?
- **Status** — is the project alpha, beta, production? Is this stated?
- **Freshness** — does the README reference features that no longer exist, or miss features that do exist?

### 3. API Documentation (HIGH)

If the project exposes an API (REST, GraphQL, library, CLI):
- Are all public endpoints/functions documented?
- Do docs include request/response examples?
- Are error responses documented?
- Are authentication requirements documented?
- Are rate limits, pagination, and versioning documented?
- Do the documented endpoints match the actual routes in code?
- Are there endpoints in code with zero documentation?

For libraries:
- Are all exported functions/classes/types documented?
- Do docs include usage examples?
- Are edge cases and error conditions documented?

### 4. Setup & Configuration Documentation (HIGH)

Check if someone new could get the project running:
- Are all environment variables documented? Cross-reference code that reads env vars vs docs
- Are database setup steps documented? (Migrations, seed data, connection config)
- Are external service dependencies documented? (Redis, S3, third-party APIs)
- Are Docker/container setup steps documented?
- Is there a `.env.example` that matches actual required env vars?
- Are there undocumented prerequisites? (Specific runtime versions, system packages)

### 5. Accuracy Check (HIGH)

Cross-reference documentation with code:
- Do code examples in docs actually work? (Check imports, function signatures, API shapes)
- Do documented config options match actual config parsing?
- Do documented CLI flags match actual argument parsing?
- Do documented features match implemented features? (Cross-reference with `features.md`)
- Are deprecated features still documented as current?
- Are version numbers in docs current?

### 6. Inline Documentation Quality (MEDIUM)

Assess code-level documentation:
- Do complex functions have explaining comments or docstrings?
- Are public API functions documented with parameter descriptions and return types?
- Are non-obvious algorithms or business logic explained?
- Do comments describe "why" not just "what"?
- Are there stale comments that describe code that has changed?
- Are TODO/FIXME/HACK comments tracked or abandoned?

### 7. Produce Findings

Write findings with this structure per finding:

```
## [SEVERITY] Finding Title

**Category**: Missing Doc | Stale Doc | Inaccurate Doc | Incomplete Doc | Inline Doc
**Location**: file/path (or "missing — should be at path")
**Severity**: CRITICAL | HIGH | MEDIUM | LOW

**Problem**: What documentation gap or issue exists.

**Impact**: Who is affected and how (new contributors confused, users can't onboard, wrong API calls, etc.).

**Recommendation**: Specific fix — what to write, where to put it, what to update.
```

Severity levels:
- **CRITICAL** — Missing README, completely undocumented public API, setup guide that doesn't work
- **HIGH** — Inaccurate documentation (documented behavior doesn't match code), missing setup steps that block onboarding, undocumented env vars
- **MEDIUM** — Incomplete docs (exists but gaps), stale content, missing examples
- **LOW** — Inline doc improvements, missing CHANGELOG entries, formatting issues

### 8. Summarize

End with:
- Summary table of findings by category and severity
- Documentation coverage: what percentage of public API is documented?
- Onboarding readiness: could a new developer get the project running from docs alone?
- Freshness: when were docs last meaningfully updated vs code?
- Overall documentation health: **UNDOCUMENTED** (CRITICALs — major gaps), **PARTIAL** (documented but gaps), **DOCUMENTED** (comprehensive with minor issues)

## Examples

```
User: Audit our docs before the v1.0 release.
→ Full audit. Emphasis on README quality, API docs completeness, and accuracy. Flag anything that would confuse a first-time user.
```

```
User: A new developer is joining. Is our setup guide good enough?
→ Emphasis on setup & configuration docs (§4). Try to follow the setup guide and flag anything missing.
```

```
User: Check if our API docs match the actual API.
→ Focus on API documentation accuracy (§3 + §5). Cross-reference every documented endpoint with code.
```

```
User: We haven't touched our docs in 6 months. How bad is it?
→ Full audit with emphasis on freshness/accuracy (§5). Compare doc timestamps to code change dates.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
