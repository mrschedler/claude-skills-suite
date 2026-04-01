# Shared Review Prompt Template

Prompt template used by 4 of the 5 reviewers in the panel: Sonnet subagent,
Cursor (--mode ask), Copilot, and Gemini. These are all **read-only**
reviewers — they score code but do NOT modify files.

For the Codex review+fix prompt (the only reviewer that writes files),
see `codex-reviewer.md`.

Fill in all bracketed placeholders before spawning.

Uses the **Agentic Rubrics** pattern: generate a checklist FROM the spec
before reading any code. This prevents anchoring bias where reviewers
justify what they see rather than checking what should exist.

Research basis: 002D Part 3 — Raghavendra et al. (2026), 54.2% SWE-bench
Verified using rubrics generated from task description, not from code.

**IMPORTANT**: Subagents do NOT have access to the artifact DB. Do NOT
include DB write steps in subagent prompts. The main thread extracts
the verdict text from the subagent's response and writes to DB itself.

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

## STEP 2: Stub & Placeholder Detection (automated gate)

Run this scan on all files created or modified by this work unit:
```bash
# Comment markers
grep -rn '// \.\.\.\|TODO\|FIXME\|HACK\|XXX\|PLACEHOLDER\|TEMP\|TEMPORARY' [modified-files] || true
grep -rn '// removed\|// temporary\|// stub\|// mock\|// dummy\|// for testing\|// will be replaced' [modified-files] || true

# Incomplete implementations
grep -rn 'implement later\|not yet implemented\|placeholder\|not implemented' [modified-files] || true
grep -rn 'throw new Error.*not implemented\|raise NotImplementedError\|todo!(\|unimplemented!(' [modified-files] || true

# Empty bodies and swallowed errors
grep -rn 'catch.*{[[:space:]]*}\|except.*pass\|{ }' [modified-files] || true

# Placeholder values in non-test code
grep -rn '"test"\|"example"\|"lorem"\|"foo"\|"bar"\|"asdf"\|"changeme"\|"password"\|"secret"' [modified-files] || true
grep -rn "'axys-server'\|'test-session'\|'default-session'\|'placeholder'" [modified-files] || true

# Debug artifacts in production code (exclude test files)
grep -rn 'console\.log\|console\.debug\|debugger\|alert(' [modified-files] | grep -v '\.test\.\|\.spec\.\|__test' || true
```
If any stub/placeholder patterns are found, note them. Stubs in production code are
automatic REJECT. TODOs in test helpers or non-critical paths are MINOR_FIX.
Debug artifacts in production code are MINOR_FIX.

## STEP 2b: Integration Wiring Check

Verify the work unit's code is actually connected, not just written:
- For each new export (function, class, constant): verify it is imported/called by at least one consumer (entry point, route, test, or other module). Unused exports = MINOR_FIX.
- For each new config key or env var reference: verify it has a documented default in `.env.example` or config file. Missing config = MINOR_FIX.
- For each resource acquired (DB connection, event listener, timer, child process): verify a corresponding cleanup exists in error/shutdown/unmount paths. Missing cleanup = MINOR_FIX or REJECT if on a critical path.
- For hardcoded session IDs, connection refs, or placeholder strings where a dynamic value should be wired: automatic REJECT.

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
