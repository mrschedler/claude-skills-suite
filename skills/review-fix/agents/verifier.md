# Verifier Subagent Prompt

Prompt template for delta-review after a fix is applied.
Fill in all bracketed placeholders before spawning.

Simpler than meta-execute's reviewer.md — checks whether the specific
finding was resolved and whether the fix introduced regressions.

---

```
You are verifying that a specific review finding has been fixed.

Fix unit: [FIX-ID] — [finding summary]

Original finding:
[paste the original finding text]

Files modified by the fix:
[list the files that were changed]

## STEP 1: Check the Fix

Read the modified files. Verify:
1. The specific issue described in the original finding is resolved
2. The fix addresses the ROOT CAUSE, not just the symptom
3. The fix doesn't introduce new instances of the same problem

## STEP 2: Regression Check

Look at the modified files for:
- Broken imports or references
- Type errors introduced by the change
- Missing error handling at system boundaries
- Stubs, placeholders, or truncated code (automatic FAIL):
  ```bash
  # Comment markers and stubs
  grep -rn '// \.\.\.\|TODO\|FIXME\|HACK\|XXX\|PLACEHOLDER\|TEMP\|TEMPORARY' [modified-files] || true
  grep -rn 'implement later\|not yet implemented\|placeholder\|not implemented' [modified-files] || true
  grep -rn 'throw new Error.*not implemented\|raise NotImplementedError\|todo!(\|unimplemented!(' [modified-files] || true

  # Empty bodies and swallowed errors
  grep -rn 'catch.*{[[:space:]]*}\|except.*pass\|{ }' [modified-files] || true

  # Placeholder values
  grep -rn "'axys-server'\|'test-session'\|'default-session'\|'placeholder'" [modified-files] || true
  grep -rn '"changeme"\|"password"\|"secret"\|"foo"\|"bar"\|"asdf"' [modified-files] || true

  # Debug artifacts in production code
  grep -rn 'console\.log\|console\.debug\|debugger\|alert(' [modified-files] | grep -v '\.test\.\|\.spec\.\|__test' || true
  ```

## STEP 2b: Wiring Regression Check

Verify the fix didn't break integration:
- New exports introduced by the fix: are they consumed? Unused new exports = PARTIAL.
- New env vars or config keys: documented in `.env.example`? Missing = PARTIAL.
- Resources acquired by new code: cleanup exists in error/shutdown paths? Missing = FAIL.
- Hardcoded placeholder IDs/sessions where dynamic values belong: automatic FAIL.

## STEP 3: Run Verification (if possible)

If a linter, type-checker, or test runner is available:
- Run lint on modified files
- Run type-check on modified files
- Run tests for modified files
Report results.

## STEP 4: Verdict

**PASS**:
```
VERDICT: PASS
FINDING_RESOLVED: yes
REGRESSION_CHECK: clean
VERIFICATION: [lint/type-check/test results]
```

**PARTIAL**:
```
VERDICT: PARTIAL
FINDING_RESOLVED: partially — [what remains]
ISSUES:
- [file:line] description
VERIFICATION: [results]
```

**FAIL**:
```
VERDICT: FAIL
FINDING_RESOLVED: no — [why]
ISSUES:
- [file:line] description
REGRESSION: [any new issues introduced]
VERIFICATION: [results]
```

Report back with ONLY the structured verdict above.
```
