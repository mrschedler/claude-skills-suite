---
name: breaking-change-review
description: Detects breaking API, dependency, and schema changes before they ship. Use before major version bumps, dependency upgrades, or API releases.
---

# Breaking Change Review

Catches breaking changes before they reach consumers. Scans for removed or
modified public APIs, changed function signatures, altered DB schemas, bumped
major dependencies, and config format changes that will break downstream code,
clients, or deployments.

This skill exists because breaking changes are the #1 cause of deployment
rollbacks, and they're easy to miss in large diffs — especially when LLMs
refactor code without considering downstream impact.

## Inputs

- The full codebase (current state)
- Git history — `git diff` against the comparison base (main, last tag, or user-specified ref)
- `project-context.md` — to understand what's public API vs internal
- `package.json` / `pyproject.toml` / `go.mod` — dependency versions
- API specs if present (OpenAPI, GraphQL schema, protobuf definitions)

## Outputs

See `references/review-lens-framework.md` for the shared output pattern.
Lens name for DB operations: `breaking-change-review`

## Instructions

### Fresh Findings Check

See `references/review-lens-framework.md`. Lens: `breaking-change-review`.

### 1. Determine Comparison Base

Identify what to diff against:
- If the user specifies a ref (tag, branch, commit), use it
- If the project has tags, use the most recent tag: `git describe --tags --abbrev=0`
- If on a feature branch, use the merge base: `git merge-base HEAD main`
- If nothing else, use `HEAD~10` as a rough window

Report the comparison base to the user before proceeding.

### 2. Public API Surface Changes (CRITICAL)

Identify what constitutes the public API:
- Exported functions, classes, types, and interfaces
- HTTP/REST endpoints (routes, methods, request/response shapes)
- GraphQL schema (types, queries, mutations, subscriptions)
- gRPC/protobuf service definitions
- CLI commands and flags
- Configuration file formats (env vars, YAML/JSON config)
- Database schema (tables, columns, constraints) — if consumers read the DB directly

Scan for changes to the public API surface:

**Removals** (always CRITICAL):
- Deleted exported functions, classes, types, or constants
- Removed HTTP endpoints or GraphQL fields
- Dropped CLI commands or flags
- Removed env vars or config keys
- Dropped DB columns or tables

**Signature changes** (usually CRITICAL):
- Changed function parameter types, order, or count
- Changed return types
- Made optional parameters required
- Changed HTTP method (GET → POST) or path
- Changed request/response body shapes
- Changed enum values or union types

**Behavioral changes** (HIGH):
- Changed default values for parameters or config
- Changed error types or error codes returned
- Changed sort order, pagination behavior, or filtering logic
- Changed authentication/authorization requirements
- Changed rate limits or quotas

### 3. Dependency Breaking Changes (HIGH)

Check dependency version bumps for breaking changes:
- Any major version bumps (semver X.0.0)? These signal intentional breaking changes
- Read changelogs/release notes for major bumps to identify what broke
- Are peer dependency requirements still satisfied?
- Did a transitive dependency bump its major version?
- Were dependencies removed that downstream consumers might rely on?
- Did the minimum required runtime version change (Node.js, Python, Go)?

### 4. Schema & Migration Changes (CRITICAL)

If the project has database migrations or schema files:
- Are there destructive migrations? (DROP TABLE, DROP COLUMN, ALTER COLUMN type change)
- Are migrations reversible? (Do down migrations exist?)
- Will migrations require downtime? (Large table ALTERs, index creation without CONCURRENTLY)
- Are schema changes backwards-compatible with the previous application version? (Critical for rolling deploys)
- Were foreign key constraints added that could fail on existing data?

### 5. Configuration & Environment Changes (HIGH)

Check for config changes that break existing deployments:
- New required environment variables without defaults
- Changed env var names or formats
- Changed config file schema (new required fields, removed fields)
- Changed Docker image entrypoint, CMD, or expected volumes
- Changed port numbers or bind addresses
- Changed feature flag names or defaults

### 6. Cross-Reference with Docs

If API documentation, READMEs, or migration guides exist:
- Are breaking changes documented?
- Is there a migration guide for consumers?
- Does the changelog mention the breaking changes?
- If using semver, does the version bump match the change severity? (Breaking change without major bump = violation)

### 7. Produce Findings

Write findings with this structure per finding:

```
## [SEVERITY] Finding Title

**Category**: API Removal | Signature Change | Behavioral Change | Dependency | Schema | Configuration
**Location**: file/path:line (or dependency name)
**Comparison**: before → after
**Severity**: CRITICAL | HIGH | MEDIUM | LOW

**What changed**: Specific description of the change.

**Who is affected**: Which consumers, clients, or deployments break.

**Evidence**: Diff snippet or before/after comparison.

**Migration path**: How consumers should adapt to this change.
```

Severity levels:
- **CRITICAL** — Removed or renamed public API, destructive schema migration, or changed contract that will cause runtime errors for consumers
- **HIGH** — Behavioral change that alters expected output, major dependency bump with known breaking changes, new required config without defaults
- **MEDIUM** — Changed defaults that may surprise consumers, deprecated API still present but behavior changed
- **LOW** — Internal refactoring that accidentally leaked into public API, documentation gap for an otherwise minor change

### 8. Summarize

End with:
- Summary table of breaking changes by category and severity
- Semver recommendation: Is this a MAJOR, MINOR, or PATCH release?
- Migration guide draft (if CRITICAL findings exist)
- Rollback risk assessment: Can this be safely rolled back if it breaks production?
- Overall verdict: **BREAKING** (has CRITICALs — needs migration guide), **CAUTIOUS** (HIGHs — needs review), **COMPATIBLE** (no breaking changes detected)

## Execution Mode

See `references/review-lens-framework.md`. Lens: `breaking-change-review`.

## Examples

```
User: We're about to cut a release. Check for breaking changes.
→ Full scan against the latest tag. Report BREAKING/CAUTIOUS/COMPATIBLE verdict. Draft migration guide if needed.
```

```
User: I bumped React from v18 to v19. What breaks?
→ Focus on dependency breaking changes (§3). Read React 19 changelog. Cross-reference with project usage.
```

```
User: Review this PR for breaking API changes.
→ Diff against the PR base branch. Focus on public API surface (§2) and config changes (§5).
```

```
User: We're changing the database schema. Is it safe?
→ Focus on schema & migration changes (§4). Check backwards compatibility for rolling deploys.
```

---

Before completing, read and follow `../references/review-lens-framework.md` and `../references/cross-cutting-rules.md`.
