---
name: completeness-review
description: Scans for stubs, TODOs, placeholders, empty bodies, and unfinished code. Use before deployment or marking anything "done," especially after AI-assisted builds.
---

# Completeness Review

## Inputs

- The full codebase
- GROUNDING.md — to understand what should be built
- Any project plan, feature list, or requirements doc if available

## Outputs

See `references/review-lens-framework.md` for the shared output pattern.

## Instructions

### Fresh Findings Check

See `references/review-lens-framework.md`.

### 1. Pattern Scan

Search the entire codebase for these patterns. Use grep for speed, then read
context around each match to assess real issue vs false positive.

**Comment markers:**
`TODO`, `FIXME`, `HACK`, `XXX`, `PLACEHOLDER`, `TEMP`, `TEMPORARY`,
`// removed`, `// stub`, `// mock`, `// dummy`, `// for testing`,
`// will be replaced`

**Debug artifacts:**
`console.log` (in production code, not tests), `console.debug`, `debugger`,
`print(` in non-logging contexts, `alert(` in production JS

**Incomplete implementations:**
- Empty function bodies (`{}` with nothing inside)
- Functions that only contain `pass`, bare `return`, or `throw new Error("not implemented")`
- Functions returning hardcoded values that should be dynamic
- Empty catch blocks (errors swallowed silently)
- Switch/match with missing cases or empty default
- `any` type annotations as shortcuts in TypeScript

**Placeholder values:**
`"test"`, `"example"`, `"foo"`, `"bar"`, `"changeme"`, `"password"`,
`"http://localhost"` in production config, `"test@test.com"` in prod code,
`1234`/`9999` as IDs in non-test code

**Commented-out code:**
- Large blocks (>5 lines) of commented code
- Commented-out imports or function calls

### 2. Feature Completeness Verification

If a project plan, GROUNDING.md, or feature list exists:
- For each feature described, trace from entry point to data layer
- Verify each step has a real implementation (not a stub)
- Check that error cases are handled, not just the happy path
- A feature is "complete" only when the full flow works end-to-end

### 3. Produce Findings

```
## [SEVERITY] Finding Title

**Category**: TODO/FIXME | Debug Artifact | Stub/Placeholder | Empty Handler |
              Commented Code | Incomplete Feature | Missing Deliverable
**Location**: file/path:line
**Pattern matched**: The exact text that triggered this finding.
**Impact**: What breaks or is missing.
**Recommendation**: What needs to be implemented.
```

Severity:
- **CRITICAL** — Feature marked "done" that's stubbed, or empty error handler in critical path
- **HIGH** — TODO in production code path, placeholder values reaching users
- **MEDIUM** — Debug artifacts in production, commented-out code blocks
- **LOW** — Cosmetic TODOs, aspirational comments

### 4. Summarize

- Total count by pattern type
- Count by severity
- Completeness score — rough % of features genuinely complete vs stubbed
- Top 5 most critical incompletions
- Overall: shippable, or needs a completion pass?

## Examples

```
User: Is this project actually done or are there stubs hiding?
→ Full pattern scan plus feature verification.
```

```
User: We built this over 10 sessions. Find everything left behind.
→ Emphasis on truncation patterns — multi-session work is highest risk.
```

---

Before completing, read and follow `../references/review-lens-framework.md` and `../references/cross-cutting-rules.md`.
