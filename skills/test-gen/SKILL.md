---
name: test-gen
description: Generates tests from test-review findings or for untested code. Use after test-review or when adding coverage to a module.
disable-model-invocation: true
---

# Test Gen

## Purpose

Close the gap between finding test problems and fixing them. test-review identifies
coverage gaps, stub tests, and missing error paths — but generating good tests requires
domain-specific strategy: fixture design, edge case enumeration, framework idioms, and
avoiding the exact LLM test anti-patterns that test-review catches. This skill generates
tests that would pass test-review's scrutiny.

## Inputs

- test-review findings from the artifact DB (if available):
  ```bash
  source artifacts/db.sh
  FINDINGS=$(db_read 'test-review' 'findings' 'standalone')
  ```
- The source file(s) to generate tests for
- Existing test files (to match conventions, framework, and patterns)
- Test configuration (jest.config, pytest.ini, vitest.config, etc.)
- `features.md` — to understand feature context for meaningful assertions

## Outputs

- Generated test files in the project's test directory structure
- Test run results (pass/fail for each generated test)
- Summary of what was generated and coverage impact

## Instructions

### 1. Load Context

Read the project's test setup:
- What test framework is used? (Jest, Vitest, pytest, Go testing, etc.)
- Where do tests live? (co-located, `__tests__/`, `test/`, `spec/`)
- What naming convention? (`*.test.ts`, `*_test.go`, `test_*.py`)
- What patterns do existing tests follow? (AAA, describe/it, fixtures, factories)
- Read 2-3 existing test files to learn the project's testing style

If no test infrastructure exists yet, ask the user which framework to use before
proceeding.

### 2. Identify Targets

Determine what needs tests. Two modes:

**From test-review findings** (preferred):
```bash
source artifacts/db.sh
FINDINGS=$(db_read 'test-review' 'findings' 'standalone')
```
If findings exist, parse them and prioritize:
1. CRITICAL findings first (zero coverage on core features, tests that always pass)
2. HIGH findings (missing error paths, stub tests, mutation gaps)
3. MEDIUM findings (missing PBT, fragile tests needing rewrite)
4. Skip LOW findings unless user requests them

**From user request**:
If no test-review findings exist or the user specifies targets, use those instead.
The user may say "add tests for `src/auth/`" or "test the payment module."

### 3. Plan Test Generation

For each target, before generating:
- Read the source file to understand the public API
- Identify the behaviors to test (not the implementation details)
- List edge cases: empty input, null, boundary values, error conditions, concurrent access
- Determine fixture needs: what test data is required?
- Check if related tests exist that should be extended rather than duplicated

Present the plan to the user:
```
## Test Generation Plan

| Target | Source File | Test File | Tests to Generate | Approach |
|---|---|---|---|---|
| Auth login | src/auth/login.ts | src/auth/__tests__/login.test.ts | 8 | Unit, mock external auth provider |
| Payment | src/payments/charge.ts | src/payments/__tests__/charge.test.ts | 12 | Integration, test DB with fixtures |
```

Wait for user approval before generating.

### 4. Generate Tests

For each approved target, spawn a Sonnet subagent (`subagent_type: "general-purpose"`,
`model: "sonnet"`) with the test-worker prompt from `agents/test-worker.md`.
Fill in all placeholders before spawning:
- `[SOURCE_CODE]`: the source code to test
- `[SOURCE_PATH]`: path to the source file
- `[EXISTING_TESTS]`: 2-3 existing test files for convention matching
- `[FRAMEWORK]`: the test framework and configuration
- `[FINDING]`: the specific test-review finding being addressed (if applicable)
- `[EDGE_CASES]`: the edge cases identified in planning
- `[TEST_PATH]`: where the generated test file should go

Read `agents/test-worker.md` for the full prompt template.

**Quality guardrails** — every generated test must:
- Assert behavior, not implementation (no testing private methods)
- Use meaningful assertions (no `toBeDefined`, `toBeTruthy` on objects)
- Include at least one error/edge case test per function
- Match the project's existing test conventions exactly
- Not duplicate existing test coverage
- Avoid all anti-patterns from test-review's `references/llm-test-antipatterns.md`:
  no magic numbers, no asserting mock return values, no hallucinated APIs

### 5. Run Tests

After each subagent returns the generated test code, write it to the target file
and run the test suite:

```bash
# Detect and run the appropriate test command for just the new file
# npm test -- path/to/new.test.ts
# pytest path/to/test_new.py -v
# go test ./path/to/... -run TestNew -v
```

For each generated test file:
- Does it pass? If not, read the error and fix (up to 2 retry attempts)
- After 2 failed retries, flag for manual review — do not keep iterating

### 6. Report

Present results:
- Files generated (with paths and line counts)
- Tests per file: total, passing, failing
- Coverage impact (if coverage tool is available): before and after delta
- Any tests that required manual intervention or couldn't be auto-fixed
- Findings from test-review that were addressed vs. skipped and why
- Next step suggestion: "Run `/test-review` to verify the new tests pass scrutiny."

## Examples

```
User: Generate tests for the gaps test-review found.
→ Read test-review findings from DB. Prioritize by severity. Plan, approve, generate, run, report.
```

```
User: Add tests for src/utils/
→ No test-review findings needed. Scan src/utils/ for untested exports. Plan tests. Generate.
```

```
User: The auth module has zero tests. Fix that.
→ Read auth source files. Identify all public functions. Generate comprehensive tests
  including happy paths, auth failures, token expiry, and rate limiting.
```

```
User: Generate property-based tests for the parser.
→ Identify parser functions. Generate PBT using the appropriate framework
  (fast-check, Hypothesis, proptest). Focus on roundtrip and idempotency properties.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
