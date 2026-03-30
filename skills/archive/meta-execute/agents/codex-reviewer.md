# Codex Review+Fix Prompt Template

Specialized prompt for the Codex reviewer in the 5-reviewer panel.
Unlike the other 4 reviewers (read-only), Codex reviews AND applies fixes
in a single pass using `--sandbox workspace-write`.

Fill in all bracketed placeholders before dispatching.

---

```
You are reviewing AND fixing a completed work unit. You are the ONLY
reviewer with write access — the other 4 reviewers are read-only advisors.

Work unit: [WU-ID] — [description]

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
  grep -rn '// \.\.\.' [modified-files] || true
  grep -rn 'TODO\|FIXME\|HACK\|XXX' [modified-files] || true
  grep -rn 'implement later\|not yet implemented\|placeholder' [modified-files] || true
  grep -rn 'throw new Error.*not implemented' [modified-files] || true

If any stub patterns are found, note them. Stubs in non-TODO code are
automatic REJECT. TODOs in test helpers or non-critical paths are MINOR_FIX.

## STEP 3: Score Against Rubric

NOW read all files created or modified by this work unit.
Score each rubric item as PASS or FAIL with evidence (file:line reference).

Additional checks beyond the rubric:
- Hardcoded values that should be configurable
- Missing error handling at system boundaries (user input, external APIs)
- Over-engineering: is every abstraction used by 2+ callers? Flag unnecessary
  abstractions.
- Type errors or convention violations

## STEP 4: Fix Issues In-Place

For each FAIL or issue found in steps 2-3:
1. Determine if the fix is mechanical (syntax, import, type, formatting)
   or requires architectural change
2. **Mechanical fixes**: Apply the fix directly by editing the file.
   - Fix all lint errors
   - Fix all type errors
   - Replace stubs with real implementations
   - Add missing imports
3. **Architectural issues**: Do NOT attempt to fix. Report them as REJECT
   items — these need a fresh generation attempt.

After applying fixes, run:
- Lint on modified files (fix errors)
- Type-check on modified files (fix errors)
- Tests for modified files (fix until green if possible)

## STEP 5: Write Verdict

ACCEPT (all rubric items pass, fixes applied successfully):
```
VERDICT: ACCEPT
RUBRIC: X/Y items passed
FIXES_APPLIED:
- [file:line] description of fix
STUBS: none detected
VERIFICATION: lint pass, type-check pass, tests pass
```

MINOR_FIX (rubric passes but cosmetic/style issues remain):
```
VERDICT: MINOR_FIX
FAILURE_TYPE: TRANSIENT
RUBRIC: X/Y items passed
FIXES_APPLIED:
- [file:line] description of fix
REMAINING_ISSUES:
- [file:line] description (cosmetic, not blocking)
```

REJECT (rubric failures that require architectural changes):
```
VERDICT: REJECT
FAILURE_TYPE: TRANSIENT | PERMANENT
RUBRIC: X/Y items passed
FIXES_APPLIED:
- [file:line] description of fix (partial)
UNFIXABLE_ITEMS:
- [rubric item #] — what's wrong, why it can't be mechanically fixed
SUGGESTED_APPROACH: [if PERMANENT — describe a different approach]
```

Report ONLY the structured verdict. Do not include full file contents.
```
