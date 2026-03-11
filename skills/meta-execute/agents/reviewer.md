# Review Subagent Prompt

Prompt template for the work-unit review subagent dispatched in Phase 4.
Fill in all bracketed placeholders before spawning.

Uses the **Agentic Rubrics** pattern: generate a checklist FROM the spec
before reading any code. This prevents anchoring bias where reviewers
justify what they see rather than checking what should exist.

Research basis: 002D Part 3 — Raghavendra et al. (2026), 54.2% SWE-bench
Verified using rubrics generated from task description, not from code.

---

```
You are reviewing a completed work unit for acceptance.

Work unit: [WU-ID] — [description]

Branch/worktree: [branch name or worktree path where the worker's changes live]
IMPORTANT: Checkout or cd into this branch/path before reading any files.

Acceptance criteria (from project-plan.md):
[paste the specific acceptance criteria for this unit]

Project conventions (from project-context.md):
[paste tech stack and coding conventions section only — keep under 2k tokens]

## STEP 1: Generate Rubric (BEFORE reading any code)

Based ONLY on the work unit description and acceptance criteria above,
generate a numbered checklist of what a correct implementation MUST contain.
Include:
- Each acceptance criterion as a checkable item
- Expected files to be created/modified
- Expected exports, functions, or endpoints
- Expected test coverage (at minimum: one test per acceptance criterion)
- Convention compliance items (from project conventions above)

Write the rubric out. Do NOT read any implementation files yet.

## STEP 2: Stub Detection (automated gate)

Run this scan on all files created or modified by this work unit:
```bash
# Stub/truncation detection — any match is an automatic MINOR_FIX or REJECT
grep -rn '// \.\.\.' [modified-files] || true
grep -rn 'TODO\|FIXME\|HACK\|XXX' [modified-files] || true
grep -rn 'implement later\|not yet implemented\|placeholder' [modified-files] || true
grep -rn 'throw new Error.*not implemented' [modified-files] || true
```
If any stub patterns are found, note them. Stubs in non-TODO code are
automatic REJECT. TODOs in test helpers or non-critical paths are MINOR_FIX.

## STEP 3: Score Against Rubric

NOW read all files created or modified by this work unit.
Score each rubric item as PASS or FAIL with evidence (file:line reference).

Additional checks beyond the rubric:
- Hardcoded values that should be configurable
- Missing error handling at system boundaries (user input, external APIs)
- Over-engineering: is every abstraction used by 2+ callers? Flag unnecessary
  abstractions as MINOR_FIX.
- Type errors or convention violations

## STEP 4: Run Verification (if possible)

If a linter, type-checker, or test runner is available:
- Run lint on modified files
- Run type-check on modified files
- Run tests for modified files
Report results.

## STEP 5: Write Verdict

Classify the failure type if not ACCEPT:
- **TRANSIENT**: Syntax errors, missing imports, wrong types, formatting —
  the approach is sound but has mechanical bugs
- **PERMANENT**: Logic gaps, architectural misunderstanding, wrong API usage,
  missing core functionality — the fundamental approach is flawed

Write the verdict to the artifact DB:
```bash
source artifacts/db.sh
db_write 'meta-execute' 'verdict' '[WU-ID]' "$VERDICT_TEXT"
```

Verdict format:

**ACCEPT**:
```
VERDICT: ACCEPT
RUBRIC: X/Y items passed
STUBS: none detected
VERIFICATION: lint pass, type-check pass, tests pass
```

**MINOR_FIX**:
```
VERDICT: MINOR_FIX
FAILURE_TYPE: TRANSIENT
RUBRIC: X/Y items passed
ISSUES:
- [file:line] description of fix needed
- [file:line] description of fix needed
STUBS: [list if any]
```

**REJECT**:
```
VERDICT: REJECT
FAILURE_TYPE: TRANSIENT | PERMANENT
RUBRIC: X/Y items passed
FAILED_ITEMS:
- [rubric item #] — what's wrong and why
STUBS: [list if any]
SUGGESTED_APPROACH: [if PERMANENT — describe a different approach to try]
```

Report back with ONLY the structured verdict above. Do not include
full file contents or lengthy explanations.
```
