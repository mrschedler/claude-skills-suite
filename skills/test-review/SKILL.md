---
name: test-review
description: Evaluates test coverage, quality, and gaps. Catches AI tendencies to skip or stub tests. Reviews strategy against project requirements to ensure critical paths are covered.
---

# Test Review

## Purpose

Evaluate whether the test suite actually protects the project. AI-generated tests
have specific failure patterns: 100% line coverage while scoring 4% on mutation
testing, asserting by "mentally executing" implementation rather than reasoning
from spec, and Magic Number Test smell at 85-99% prevalence. This catches those
patterns and identifies what's genuinely untested.

## Inputs

- The full codebase (source and test files)
- GROUNDING.md or project docs — to map features to test coverage
- Test configuration (jest.config, pytest.ini, vitest.config, etc.)
- Coverage reports if available
- Mutation testing results if available

## Outputs

See `references/review-lens-framework.md` for the shared output pattern.

## Instructions

### Fresh Findings Check

See `references/review-lens-framework.md`.

### 1. Map the Test Landscape

Inventory what exists:
- Where are tests? (co-located, `__tests__/`, `test/`, `spec/`)
- What frameworks? (Jest, Vitest, pytest, Go testing, etc.)
- What types? (unit, integration, e2e, snapshot, property-based, contract)
- Test runner config — what does it include/exclude?
- Mutation testing configured? (Stryker, PIT, mutmut, cargo-mutants)

**Test Strategy Shape** — detect architecture and assess distribution:
- Monolith/library → pyramid (unit-heavy) is correct
- SPA/frontend → trophy (integration-heavy) is correct
- Microservices → honeycomb (integration + contract heavy) is correct
- Flag mismatches and hourglass antipattern (unit + E2E heavy, no integration)

### 2. Feature-to-Test Mapping

For each feature or capability described in project docs:
- Identify which test files cover it
- Flag features with zero test coverage
- Flag features with only happy-path tests
- Flag skipped tests (`skip`, `xit`, `xtest`, `@pytest.mark.skip`)

This is the most important section. A test suite that doesn't cover the feature
list is theater, not testing.

### 3. Test Quality Audit

**Stub Detection:**
- Tests asserting `true`, `toBeDefined`, or `not.toBeNull` without checking values
- Tests with empty bodies or only logging
- `expect` calls matching mock return values exactly (testing the mock)
- Test methods with 0 assertions

**Mock Overuse** (scope: mocks of types the SUT *owns*, not external deps):
- More lines setting up mocks than asserting behavior
- Mocks replicating implementation logic
- External services mocked without integration tests to validate the mock
- Note: mocking external I/O (databases, HTTP) is correct isolation, not overuse

**Fragile Tests:**
- Dependent on execution order
- Fixed delays (`setTimeout`, `sleep`)
- Hardcoded timestamps, ports, file paths
- `new Date()` / `datetime.now()` without time injection
- Real HTTP calls without VCR/cassette recording

**Missing Error Paths:**
- Functions that throw/reject with no error-case tests
- API endpoints with no 4xx/5xx tests
- Validation logic with no boundary/invalid-input tests
- Timeout/retry paths untested

**AI-Generated Test Anti-Patterns:**
- Magic Number Test smell (hardcoded expected values with no explanation)
- Coverage theater: high line coverage, near-zero mutation score
- Hallucinated APIs: assertions on methods that don't exist
- Data model mismatch: fixtures with wrong field names/types

### 4. Mutation Testing Adequacy

- Is mutation testing configured? If results exist, parse them.
- Flag modules with score <80% (below 60% = CRITICAL)
- Thresholds: 90%+ for auth/payments, 75-90% core logic, 50-75% utilities, <50% inadequate
- If not configured, recommend for critical modules

### 5. Coverage Gaps

- Files with zero test imports
- Functions with cyclomatic complexity >10 and no tests
- Error handling code (catch blocks, fallback logic, retry mechanisms)
- Edge cases: empty inputs, null values, concurrent access
- Feature flag branches (both on/off paths)

Metrics hierarchy (most to least predictive):
```
Mutation Score > Branch Coverage > CRAP Score > Assertion Density > Line Coverage
```

### 6. Test Infrastructure

- Can tests run with one command?
- Test fixtures well-organized or duplicated?
- Test data realistic or obviously fake?
- Suite run time reasonable? (<10 min target)
- Tests isolated? No shared mutable global state?
- Parallel-safe? No port/resource conflicts?

### 7. Produce Findings

```
## [SEVERITY] Finding Title

**Category**: Coverage Gap | Stub/Fake Test | Fragile Test | Mock Overuse |
  Missing Error Path | Mutation Gap | Strategy Mismatch | AI Anti-Pattern | Infrastructure
**Location**: file/path:line (or feature name)
**Problem**: What's wrong.
**Evidence**: Code snippet or test output.
**Recommendation**: What test to write or fix. Name the function, scenario, expected behavior.
```

Severity:
- **CRITICAL** — Core feature with zero coverage, tests that always pass, mutation score <50%
- **HIGH** — Significant gap letting regressions through
- **MEDIUM** — Quality issue weakening confidence (fragile tests, mock overuse)
- **LOW** — Maintainability improvement

### 8. Summarize

- Coverage map: feature → test files → coverage level (none/partial/good)
- Findings by severity and category
- Metrics summary if data available
- Strategy assessment: does shape match architecture?
- Verdict: does this suite catch regressions, or is it decoration?

## References (on-demand)

- `references/mutation-testing-guide.md` — Tools, thresholds, CI setup
- `references/pbt-patterns.md` — Property-based testing patterns
- `references/llm-test-antipatterns.md` — AI test smell taxonomy
- `references/test-strategy-shapes.md` — Pyramid/trophy/honeycomb decision tree
- `references/metrics-reference.md` — Metrics hierarchy, CRAP score, tool flags

## Examples

```
User: How's our test coverage? Are we testing anything real?
→ Full audit with feature mapping, mutation check, strategy shape.
```

```
User: Tests pass but I don't trust them.
→ Emphasis on Stub Detection, Mock Overuse, AI Anti-Patterns, Mutation Testing.
```

---

Before completing, read and follow `../references/review-lens-framework.md` and `../references/cross-cutting-rules.md`.
