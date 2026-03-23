---
name: test-review
description: Evaluates test coverage, quality, and gaps. Catches LLM tendencies to skip or stub tests. Reviews strategy against features.md to ensure critical paths are covered.
---

# Test Review

## Purpose

Evaluate whether the test suite actually protects the project. LLM-generated tests have
specific failure patterns: they achieve 100% line coverage while scoring 4% on mutation
testing, assert by "mentally executing" implementation rather than reasoning from spec,
and exhibit Magic Number Test smell at 85-99% prevalence. This skill catches those
patterns and identifies what's genuinely untested.

## Inputs

- The full codebase (source and test files)
- `features.md` — to map features to test coverage
- Existing test configuration (jest.config, pytest.ini, vitest.config, etc.)
- Coverage reports if available (lcov, coverage.py, go cover output)
- Mutation testing results if available (Stryker, PIT, mutmut output)

## Outputs

See `references/review-lens-framework.md` for the shared output pattern.
Lens name for DB operations: `test-review`

## Instructions

### Fresh Findings Check

See `references/review-lens-framework.md`. Lens: `test-review`.

### 1. Map the Test Landscape

Inventory what exists:
- Where are tests located? (co-located, `__tests__/`, `test/`, `spec/`)
- What frameworks are used? (Jest, Vitest, pytest, Go testing, etc.)
- What types of tests exist? (Unit, integration, e2e, snapshot, contract, property-based)
- Is there a test runner config? What does it include/exclude?
- Is there a CI pipeline that runs tests? What triggers it?
- Is mutation testing configured? (Stryker, PIT, mutmut, cargo-mutants)
- Are there property-based tests? (Hypothesis, fast-check, proptest, jqwik)
- Are there contract tests? (Pact, Spring Cloud Contract, Specmatic)

**Test Strategy Shape** — Detect architecture type and assess whether the test
distribution matches:
- Monolith/library → pyramid (unit-heavy) is correct
- SPA/frontend → trophy (integration-heavy) is correct
- Microservices → honeycomb (integration + contract heavy) is correct
- Flag mismatched strategy (e.g., microservices with 90% unit / 0% integration)
- Flag hourglass antipattern (unit + E2E heavy, no integration layer)

Read `references/test-strategy-shapes.md` for the full decision tree.

### 2. Feature-to-Test Mapping

Read `features.md` and build a coverage map:
- For each feature listed, identify which test files cover it
- Flag features with zero test coverage
- Flag features with only happy-path tests
- Flag features where tests exist but are skipped (`skip`, `xit`, `xtest`, `@pytest.mark.skip`)

This is the most important section. A test suite that doesn't cover the feature list
is theater, not testing.

### 3. Test Quality Audit

For existing tests, evaluate quality across these categories:

**Stub Detection**
- Tests that assert `true`, `toBeDefined`, or `not.toBeNull` without checking values
- Tests with empty bodies or only `console.log`
- `expect` calls that match the mock's return value exactly (testing the mock)
- Tests that pass when the implementation is deleted (false positives)
- Test methods with 0 assertions (P0 finding per Microsoft Research)

**Mock Overuse** — Scope: mocks of types the SUT *owns*, not external dependencies
- Tests where more lines set up mocks than assert behavior
- Mocks that replicate implementation logic (brittle coupling)
- External services mocked without any integration test to validate the mock
- Note: mocking external I/O (databases, HTTP clients, filesystems) is correct isolation,
  not overuse. Only flag mocks of internal collaborators that could be tested with real objects.

**Fragile Tests**
- Tests dependent on execution order
- Tests using `setTimeout` or fixed delays ("Sleepy Test" smell)
- Tests with hardcoded timestamps, ports, or file paths ("Magic Number Test")
- Snapshot tests that get updated without review (auto-accept culture)
- Tests that flake in CI but pass locally
- Date/time dependencies: `new Date()`, `datetime.now()` without time injection
- Network dependencies: real HTTP calls without VCR/cassette recording
- Filesystem state: tests reading from non-fixture paths

**Missing Error Paths**
- Functions that throw/reject but have no error-case tests
- API endpoints with no tests for 4xx/5xx responses
- Validation logic with no boundary/invalid-input tests
- Exception hierarchy gaps: only testing base `Exception`, not specific types
- Timeout/retry path coverage (common in microservices)
- Partial failure scenarios in batch operations
- Resource exhaustion: connection pool full, disk full, OOM paths

**LLM-Generated Test Anti-Patterns** — Read `references/llm-test-antipatterns.md`
- Magic Number Test smell (85-99% prevalence in AI-generated tests)
- Coverage theater: high line coverage, near-zero mutation score
- Hallucinated APIs: assertions on methods/properties that don't exist
- Data model mismatch: fixtures with wrong field names or types
- Test oracle problem: assertions derived from implementation, not specification

### 4. Mutation Testing Adequacy

Check if mutation testing is configured and assess results. This is the ground truth
for test suite quality — coverage measures execution, mutation testing measures correctness.

- Is a mutation tool configured? (Stryker, PIT, mutmut, cargo-mutants, Gremlins)
- If mutation score data exists, parse it
- Flag any module with score <80% (below 60% = CRITICAL)
- VoidMethodCalls mutations with low kill rate = missing side-effect assertions
- If no mutation testing exists, recommend it for critical modules

**Score thresholds:**
- 90%+ required: auth, payments, safety-critical
- 75-90% good: core business logic
- 50-75% acceptable: utilities, non-critical
- <50% inadequate: test suite does not validate behavior

**When NOT to recommend:** prototype code, UI rendering, coverage <50% (fix coverage first)

Read `references/mutation-testing-guide.md` for tools, setup, and interpretation.

### 5. Property-Based Testing Assessment

Identify code that should have PBT but doesn't:
- Serialization pairs (encode/decode, serialize/deserialize)
- Parsers and input processors
- Normalization/canonicalization functions
- Validators and sanitizers
- Custom data structures (collections, trees, graphs)
- Mathematical/algorithmic functions
- Any function with 5+ parametrized tests using structurally similar inputs

Each PBT property catches ~50x as many mutations as the average unit test.

Read `references/pbt-patterns.md` for the 7 PBT patterns and framework-specific guidance.

### 6. Contract Testing Assessment

Only applicable to microservice/API architectures with cross-team boundaries:
- Do service-to-service calls exist? If yes, are there contract tests?
- HTTP mocks (nock, WireMock, requests_mock) with no corresponding contract file = red flag
- Integration tests spinning up real downstream services = missing contracts
- No `can-i-deploy` or equivalent CI gate = deployment risk

Read `references/contract-testing-guide.md` for tools and patterns.

### 7. Coverage Gaps

Identify untested areas using quantitative thresholds:
- Files with zero test imports (no test touches them)
- Functions with cyclomatic complexity >10 and no tests (CC >10 = industry threshold)
- CRAP score >30 = needs action, >60 = refactor before testing
- Error handling code — catch blocks, fallback logic, retry mechanisms
- Edge cases: empty inputs, null values, concurrent access, large payloads
- Configuration and environment-dependent behavior
- Feature flag branches: both on/off paths must be tested; flags constant >90 days = flag for removal

**Metrics hierarchy** (most to least predictive of test effectiveness):
```
Mutation Score > Branch Coverage > CRAP Score > Assertion Density > Line Coverage
```
Line coverage alone is not a quality signal. 80% coverage is a CI floor, not a target.

Read `references/metrics-reference.md` for full metrics detail and tool-specific flags.

### 8. Test Infrastructure

Evaluate the test setup:
- Can a new developer run tests with one command?
- Are test fixtures/factories well-organized or duplicated everywhere?
- Is test data realistic or obviously fake (`test@test.com`, `12345`)?
- Are there test utilities that are themselves untested and buggy?
- Does the test suite run in reasonable time? (target: <10 min, parallelize at >5 min)
- **Test isolation**: do tests share mutable global state? (root cause of order-dependency)
- **Parallel safety**: can the suite run in parallel without port/resource conflicts?
- **Flakiness management**: is there a quarantine system for flaky tests?
- **DB test strategy**: transaction rollback (86x speedup documented) or Testcontainers?

### 9. Produce Findings

Write findings with this structure per finding:

```
## [SEVERITY] Finding Title

**Category**: Coverage Gap | Stub/Fake Test | Fragile Test | Mock Overuse |
  Missing Error Path | Mutation Gap | Missing PBT | Missing Contract Test |
  Strategy Mismatch | LLM Anti-Pattern | Infrastructure
**Location**: file/path:line (or feature name from features.md)

**Problem**: What's wrong, specifically.

**Evidence**: Code snippet or test output showing the issue.

**Recommendation**: What test to write or fix. Be specific — name the function,
the scenario, and the expected behavior.
```

Severity levels:
- **CRITICAL** — Core feature with zero test coverage, tests that always pass, or mutation score <50%
- **HIGH** — Significant gap that could let regressions through, missing contract tests at service boundaries
- **MEDIUM** — Quality issue that weakens confidence (missing PBT, fragile tests, mock overuse)
- **LOW** — Improvement suggestion for test maintainability (naming, infrastructure)

### 10. Summarize

End with:
- A coverage map table: feature name | test files | coverage level (none/partial/good)
- Count of findings by severity and category
- Metrics summary: mutation score, branch coverage, CRAP hotspots (if data available)
- Test strategy assessment: does the shape match the architecture?
- Overall verdict: does this test suite catch regressions, or is it decoration?

## Execution Mode

See `references/review-lens-framework.md`. Lens: `test-review`.

## References (on-demand)

Read these files only when needed for the relevant section:
- `references/mutation-testing-guide.md` — Tools by language, score thresholds, incremental CI setup, equivalent mutant handling
- `references/pbt-patterns.md` — 7 PBT patterns, Trail of Bits trigger list, framework-specific guidance
- `references/contract-testing-guide.md` — Consumer-driven vs provider-driven, tools (Pact/Specmatic/Microcks), red flags
- `references/test-strategy-shapes.md` — Pyramid/trophy/honeycomb/hourglass decision tree by architecture type
- `references/llm-test-antipatterns.md` — Full smell taxonomy, detection signals, Magic Number Test, coverage theater
- `references/metrics-reference.md` — Metrics hierarchy, CRAP score formula, tool-specific coverage flags

## Examples

```
User: How's our test coverage? Are we actually testing anything real?
→ Full audit with feature mapping, mutation check, strategy shape. Produce findings.
```

```
User: Tests pass but I don't trust them.
→ Emphasis on Stub Detection, Mock Overuse, LLM Anti-Patterns, and Mutation Testing.
```

```
User: We're about to merge the auth feature. Review the tests for it.
→ Scoped to auth-related test files. Map against auth features in features.md.
  Check mutation score for auth module specifically (90%+ threshold).
```

---

Before completing, read and follow `../references/review-lens-framework.md` and `../references/cross-cutting-rules.md`.
