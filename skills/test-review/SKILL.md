---
name: test-review
description: Evaluates test coverage, quality, and gaps. Catches LLM tendencies to skip or stub tests. Reviews strategy against features.md to ensure critical paths are covered.
---

# Test Review

## Purpose

Evaluate whether the test suite actually protects the project. LLM-generated tests have
a specific failure pattern: they look comprehensive at a glance but test happy paths only,
use mocks that mirror implementation (testing the mock, not the code), or contain stubs
that always pass. This skill catches those patterns and identifies what's genuinely
untested.

## Inputs

- The full codebase (source and test files)
- `features.md` — to map features to test coverage
- Existing test configuration (jest.config, pytest.ini, vitest.config, etc.)

## Outputs

- **Standalone mode**: Store findings in the artifact DB:
  ```bash
  source artifacts/db.sh
  db_upsert 'test-review' 'findings' 'standalone' "$FINDINGS_CONTENT"
  ```
- **Multi-model mode** (called by meta-review): Store per-model findings in the artifact DB:
  - Sonnet: `db_upsert 'test-review' 'findings' 'sonnet' "$CONTENT"`
  - Codex: `db_upsert 'test-review' 'findings' 'codex' "$CONTENT"`
  - Gemini: `db_upsert 'test-review' 'findings' 'gemini' "$CONTENT"`

## Instructions

### Fresh Findings Check

Before running a new scan, check if fresh findings already exist:
```bash
source artifacts/db.sh
AGE=$(db_age_hours 'test-review' 'findings' 'standalone')
# For multi-model: db_age_hours 'test-review' 'findings' 'sonnet'
```
If `$AGE` is non-empty and less than 24, report: "Found fresh test-review findings from $AGE hours ago. Reuse them? (y/n)"
If the user says yes, read findings from DB: `db_read 'test-review' 'findings' 'standalone'` (or `sonnet`/`codex`/`gemini` as appropriate).
If no record exists or user says no, proceed with a fresh scan.

### 1. Map the Test Landscape

Inventory what exists:
- Where are tests located? (co-located, `__tests__/`, `test/`, `spec/`)
- What frameworks are used? (Jest, Vitest, pytest, Go testing, etc.)
- What types of tests exist? (Unit, integration, e2e, snapshot, contract)
- Is there a test runner config? What does it include/exclude?
- Is there a CI pipeline that runs tests? What triggers it?

### 2. Feature-to-Test Mapping

Read `features.md` and build a coverage map:
- For each feature listed, identify which test files cover it
- Flag features with zero test coverage
- Flag features with only happy-path tests
- Flag features where tests exist but are skipped (`skip`, `xit`, `xtest`, `@pytest.mark.skip`)

This is the most important section. A test suite that doesn't cover the feature list
is theater, not testing.

### 3. Test Quality Audit

For existing tests, evaluate quality:

**Stub Detection**
- Tests that assert `true`, `toBeDefined`, or `not.toBeNull` without checking values
- Tests with empty bodies or only `console.log`
- `expect` calls that match the mock's return value exactly (testing the mock)
- Tests that pass when the implementation is deleted (false positives)

**Mock Overuse**
- Tests where more lines set up mocks than assert behavior
- Mocks that replicate implementation logic (brittle coupling)
- External services mocked without any integration test to validate the mock

**Fragile Tests**
- Tests dependent on execution order
- Tests using `setTimeout` or fixed delays
- Tests with hardcoded timestamps, ports, or file paths
- Snapshot tests that get updated without review (auto-accept culture)
- Tests that flake in CI but pass locally

**Missing Error Paths**
- Functions that throw/reject but have no error-case tests
- API endpoints with no tests for 4xx/5xx responses
- Validation logic with no boundary/invalid-input tests

### 4. Coverage Gaps

Identify untested areas:
- Files with zero test imports (no test touches them)
- Complex functions (high cyclomatic complexity) with minimal tests
- Error handling code — catch blocks, fallback logic, retry mechanisms
- Edge cases: empty inputs, null values, concurrent access, large payloads
- Configuration and environment-dependent behavior

### 5. Test Infrastructure

Evaluate the test setup itself:
- Can a new developer run tests with one command?
- Are test fixtures/factories well-organized or duplicated everywhere?
- Is test data realistic or obviously fake (`test@test.com`, `12345`)?
- Are there test utilities that are themselves untested and buggy?
- Does the test suite run in reasonable time, or is it slow enough that people skip it?

### 6. Produce Findings

Write findings to the output file with this structure per finding:

```
## [SEVERITY] Finding Title

**Category**: Coverage Gap | Stub/Fake Test | Fragile Test | Mock Overuse | Missing Error Path | Infrastructure
**Location**: file/path:line (or feature name from features.md)

**Problem**: What's wrong, specifically.

**Evidence**: Code snippet or test output showing the issue.

**Recommendation**: What test to write or fix. Be specific — name the function, the
scenario, and the expected behavior.
```

Severity levels:
- **CRITICAL** — Core feature with zero test coverage, or tests that always pass (false safety)
- **HIGH** — Significant gap that could let regressions through
- **MEDIUM** — Quality issue that weakens confidence in the test suite
- **LOW** — Improvement suggestion for test maintainability

### 7. Summarize

End with:
- A coverage map table: feature name | test files | coverage level (none/partial/good)
- Count of findings by severity and category
- Overall assessment: does this test suite catch regressions, or is it decoration?

## Execution Mode

- **Standalone**: Spawn the `review-lens` agent (`subagent_type: "review-lens"`) with this skill's lens instructions and input files. Stores findings in DB as `db_upsert 'test-review' 'findings' 'standalone'`.
- **Via meta-review**: The `review-lens` agent runs the Sonnet review, while Codex (`/codex`) and Gemini (`/gemini`) run in parallel with the same prompt. Each model stores findings in DB under label `sonnet`, `codex`, or `gemini`. The meta-review skill handles synthesis.

## Examples

```
User: How's our test coverage? Are we actually testing anything real?
→ Triggers test-review. Full audit with feature mapping. Produce findings.
```

```
User: Tests pass but I don't trust them. Can you check if they're actually testing anything?
→ Triggers test-review with emphasis on Stub Detection and Mock Overuse sections.
```

```
User: We're about to merge the auth feature. Review the tests for it.
→ Triggers test-review scoped to auth-related test files. Map against auth features
  in features.md.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
