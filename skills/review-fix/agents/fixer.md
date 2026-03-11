# Fixer Worker Prompt Template

Prompt template for Codex/Sonnet workers dispatched in Phase 3.
Fill in all bracketed placeholders before spawning.

Simpler than meta-execute's worker.md — scoped to fixing specific review
findings rather than building new features.

---

```
<rules>
CRITICAL RULES — read these first and last:
- Output COMPLETE files only. Never truncate. Never use "// ..." or "// rest remains the same".
- Fix ONLY what the finding describes. Do not refactor surrounding code.
- Do not add features, comments, or "improvements" beyond the fix.
- If the fix requires changes to files not listed in your context, STOP and report back.
</rules>

<task>
Fix unit: [FIX-ID] — [finding summary]

Original review finding:
[paste the full finding text including severity, confidence, and file:line references]

Required fix:
[paste the specific fix description from the user-approved list]
</task>

<context>
Project conventions (keep under 2k tokens):
[paste tech stack and coding conventions from project-context.md — NOT the full file]

Files to modify:
[paste full contents of ONLY the files this fix touches]

Interface signatures for imported modules:
[paste type signatures / exports of modules these files import — NOT their implementations]
</context>

<scope-protocol>
This is a TARGETED FIX. Your scope is strictly limited:

IN SCOPE:
→ Changes that directly resolve the finding described above
→ Fixing collateral damage from the fix (e.g., broken imports after moving code)
→ Adding/updating tests that cover the fix

OUT OF SCOPE:
→ Refactoring code near the fix
→ Fixing unrelated issues you notice
→ Adding documentation or comments beyond the fix
→ Changing code style or formatting in untouched lines

If you discover something out of scope, add a single-line TODO comment and move on.
</scope-protocol>

<output-format>
STEP 1 — Diagnose:
Explain what's wrong and why the current code causes the issue described in the finding.
If the finding is a false positive (the code is actually correct), explain why and STOP.

STEP 2 — Fix:
Write complete files with the fix applied. Every function has a real body.

STEP 3 — Verify:
After writing each file:
  a) Run lint if configured — fix all errors
  b) Run type-check if applicable — fix all errors
  c) Run tests for modified files — fix until green
  d) If no tests cover this fix, write at least one test verifying the fix

STEP 4 — Summary:
- Files modified (with line counts)
- What was changed and why
- Tests run and results
- False positive? (yes/no — if yes, explain)
</output-format>

<rules>
REMINDER — re-read before finishing:
- Every file must be COMPLETE. No truncation. No stubs.
- Fix ONLY the finding. Do not refactor, improve, or expand scope.
- Tests must pass before reporting success.
</rules>
```
