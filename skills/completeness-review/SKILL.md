---
name: completeness-review
description: Scans for stubs, TODOs, placeholders, empty bodies, and unfinished code. Use before deployment or marking anything "done," especially after LLM-assisted builds.
---

# Completeness Review

## Purpose

Catch unfinished work. This addresses the single most common failure mode in LLM-assisted
development: code that looks complete but contains stubs, placeholder values, TODO
comments, empty error handlers, and functions that return hardcoded data instead of
real implementations. These slip through because they compile, they don't crash on
happy paths, and they look like real code at a glance.

## Inputs

- The full codebase
- `project-plan.md` — to verify phase deliverables are actually implemented
- `features.md` — to verify feature implementations are complete, not stubbed

## Outputs

See `references/review-lens-framework.md` for the shared output pattern.
Lens name for DB operations: `completeness-review`

## Instructions

### Fresh Findings Check

See `references/review-lens-framework.md`. Lens: `completeness-review`.

### 1. Pattern Scan

Search the entire codebase for these patterns. Use grep/ripgrep for speed, then read
context around each match to assess whether it's a real issue or a false positive.

**Comment markers:**
- `TODO`
- `FIXME`
- `HACK`
- `XXX`
- `PLACEHOLDER`
- `TEMP` / `TEMPORARY`
- `// removed`
- `// temporary`
- `// stub`
- `// mock`
- `// dummy`
- `// for testing`
- `// will be replaced`

**Debug artifacts:**
- `console.log` (in production code, not test files)
- `console.debug`
- `console.warn` used as error handling
- `debugger` statements
- `print(` in non-Python languages or non-logging Python code
- `alert(` in production JavaScript
- `System.out.println` in production Java

**Incomplete implementations:**
- Empty function bodies (`{}` or `{ }` with nothing inside)
- Functions that only contain `pass` (Python), `return` with no value, or `throw new Error("not implemented")`
- Functions returning hardcoded values (strings, numbers, arrays) that should be dynamic
- Empty catch blocks (`catch (e) {}` — error swallowed silently)
- Switch/match with missing cases or a default that does nothing
- `any` type annotations used as shortcuts in TypeScript

**Placeholder values:**
- `"test"`, `"example"`, `"lorem ipsum"`, `"foo"`, `"bar"`, `"asdf"`
- `"http://localhost"` or `"127.0.0.1"` in production config (not dev config)
- `"changeme"`, `"password"`, `"secret"`, `"xxx"`, `"yyy"`
- `1234`, `9999`, `0000` as IDs or ports in non-test code
- `"test@test.com"`, `"user@example.com"` in production code

**Commented-out code:**
- Large blocks of commented code (more than 5 lines) — indicates abandoned attempts
- Commented-out imports — were these needed?
- Commented-out function calls — was this logic supposed to run?

### 2. Feature Completeness Verification

For each feature in `features.md` marked as done or in-progress:
- Trace the feature from entry point to data layer
- Verify each step in the flow has a real implementation (not a stub or shortcut)
- Check that error cases are handled (not just the happy path)
- Verify that the feature's edge cases are covered (empty inputs, invalid data, concurrent access)

A feature is "complete" only when the full flow works end-to-end with proper error
handling. A feature that works on the happy path but crashes on invalid input is not
complete.

### 3. Plan Deliverable Verification

For each deliverable listed in `project-plan.md`:
- Find the implementing code
- Verify it's a real implementation, not a skeleton or stub
- Flag deliverables with no corresponding code at all

### 4. Produce Findings

Format each finding using this structure (store via `db_upsert` as shown in Outputs above):

```
## [SEVERITY] Finding Title

**Category**: TODO/FIXME | Debug Artifact | Stub/Placeholder | Empty Handler |
              Commented Code | Incomplete Feature | Missing Deliverable
**Location**: file/path:line

**Pattern matched**: The exact text or code pattern that triggered this finding.

**Context**: What this code is supposed to do (based on function name, surrounding code,
or doc references).

**Impact**: What breaks or is missing because of this incompleteness.

**Recommendation**: What needs to be implemented. Be specific about the expected behavior.
```

Severity levels:
- **CRITICAL** — Feature marked "done" that's actually stubbed, or empty error handler
  in a critical path (data loss risk)
- **HIGH** — TODO in production code path, placeholder values that will reach users,
  hardcoded test data in production
- **MEDIUM** — Debug artifacts in production, commented-out code blocks, missing edge
  case handling
- **LOW** — Cosmetic TODOs, aspirational comments ("could optimize this later"),
  non-critical debug logging

### 5. Summarize

End with:
- Total count of each pattern type found
- Count of findings by severity
- A "completeness score" — rough percentage of features that are genuinely complete
  vs stubbed
- Top 5 most critical incompletions (the ones that would embarrass you in a demo)
- Overall assessment: is this project shippable, or does it need a completion pass?

## Execution Mode

See `references/review-lens-framework.md`. Lens: `completeness-review`.

## Examples

```
User: Is this project actually done or are there stubs hiding in there?
→ Triggers completeness-review. Full pattern scan plus feature verification.
```

```
User: We built this over 10 sessions with Claude. Find everything that got left behind.
→ Triggers completeness-review. Emphasis on truncation patterns (commented code, partial
  implementations) since multi-session work is the highest risk for these.
```

```
User: Scan for TODOs and placeholders before we ship.
→ Triggers completeness-review. Pattern scan with prioritization by proximity to
  user-facing code paths.
```

---

Before completing, read and follow `../references/review-lens-framework.md` and `../references/cross-cutting-rules.md`.
