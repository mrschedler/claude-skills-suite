# Worker Prompt Template

Prompt template for Codex/Sonnet workers dispatched in Phase 3.
Fill in all bracketed placeholders before spawning.

Research basis: 002D Parts 2, 6, 8, 9 — XML tagging, full-file contract,
plan-before-code, scope creep protocol, inline quality gates.

---

```
<rules>
CRITICAL RULES — read these first and last:
- Output COMPLETE files only. Never truncate. Never use "// ..." or "// rest remains the same".
- No stubs, no "implement later", no placeholder functions with empty bodies.
- No over-engineering: every abstraction must be used by 2+ callers. Prefer 3 similar lines over a premature helper.
- If you are uncertain about an approach, generate a plan FIRST (see <output-format>).
</rules>

<task>
Work unit: [WU-ID] — [description]

Acceptance criteria:
[paste the specific acceptance criteria for this unit]
</task>

<context>
Project conventions (keep under 2k tokens):
[paste tech stack and coding conventions from project-context.md — NOT the full file]

Files to modify:
[paste full contents of ONLY the files this unit modifies]

Interface signatures for imported modules:
[paste type signatures / exports of modules this unit imports — NOT their implementations]

Relevant type definitions:
[paste shared types, constants, enums referenced by this unit]
</context>

<scope-creep-protocol>
If you discover work not in your task description:

LOW BLAST RADIUS (missing utility, undefined helper, small gap):
→ Assume a reasonable implementation and continue.
→ Add a TODO comment with a clear interface signature.
→ Report what you assumed in your output summary.

HIGH BLAST RADIUS (missing service, schema change, security decision, new external dependency):
→ STOP immediately.
→ Do NOT guess or implement a workaround.
→ Report back: what's missing, why you can't proceed, suggested resolution.
</scope-creep-protocol>

<output-format>
STEP 1 — Plan before coding:
List every file you will create or modify and summarize what changes each gets.
If your plan exceeds 200 LOC of changes, WARN in your output summary — the unit
may need splitting. Continue if you're confident, but flag it for the orchestrator.

STEP 2 — Implement:
Write complete files. Every function has a real body. Every import resolves.

STEP 3 — Inline quality gates (MANDATORY):
After writing each file:
  a) Run lint if a linter is configured (eslint, ruff, etc.) — fix all errors
  b) Run type-check if applicable (tsc --noEmit, mypy, pyright) — fix all errors
After all files are written:
  c) Run unit tests for modified files — fix until green
  d) If no tests exist for this unit, write at least one test covering the primary acceptance criterion

You CANNOT report success until step 3 passes. If tests fail after 3 attempts,
report the failure with the test output — do not skip tests.

STEP 4 — Output summary:
- Files created/modified (with line counts)
- Tests run and results
- Any assumptions made (from scope-creep-protocol)
- Any blockers encountered
</output-format>

<rules>
REMINDER — re-read before finishing:
- Every file must be COMPLETE. No truncation. No stubs. No "implement later".
- Every abstraction must be justified by 2+ callers.
- Tests must pass before reporting success.
</rules>
```
