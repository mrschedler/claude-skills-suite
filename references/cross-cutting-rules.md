# Cross-Cutting Rules

These rules apply to every skill in the suite. Every atomic SKILL.md must follow them before completing.

## Rules

1. **Follow coterie.md** — Check and respect coterie rules in the project root. If `coterie.md` does not exist, create it from the coterie template before proceeding.

2. **Log to cnotes.md** — Notable decisions, context changes, and rationale. If `cnotes.md` does not exist, create it with the header `# Collaboration Notes` and `## Notes (Newest First)` before logging. This is also enforced by the Stop hook, but skills should do this proactively.

3. **Update todo.md** — Any new action items discovered during execution.

4. **Update features.md** — Any feature changes or discoveries.

5. **CLI concurrency limits (MANDATORY)** — Never exceed these simultaneous process counts:
   - **Codex**: max **5** concurrent `codex exec` processes
   - **Gemini**: max **2** concurrent `gemini` processes
   - If a skill needs more, queue excess and launch as slots free up. Do NOT launch all at once.
   - These limits come from `general.md` and override any per-skill instructions.

## Structured Note Schema

Every note in `cnotes.md` uses this format. Insert newest first (top insertion below `## Notes (Newest First)`). Once a newer note exists above yours, your note is locked — do not modify it.

### Delimiter Format

Each agent uses its own delimiter:
```
---CLAUDE--------------------
[note body]
------------------------------

---CODEX---------------------
[note body]
-------------------------------

---GEMINI-------------------
[note body]
------------------------------

---COPILOT------------------
[note body]
------------------------------
```

### Required Fields (all 13)

1. `note_id`: `CN-YYYYMMDD-HHMMSS-AUTHOR` (e.g., `CN-20260306-143022-CLAUDE`)
2. `timestamp_utc`: ISO-8601 UTC
3. `author`: `CLAUDE`, `CODEX`, `GEMINI`, or `COPILOT`
4. `activity_type`: `CODE_WRITE` or `CODE_REVIEW`
5. `work_scope`: Short statement of task intent
6. `files_touched`: Files edited (or `none`)
7. `files_reviewed`: Files reviewed (or `none`)
8. `summary`: Concise outcome summary
9. `details`: Specific changes or findings
10. `validation`: Tests/checks executed (or `not run`)
11. `risks_or_gaps`: Known risks, assumptions, or unresolved items
12. `handoff_to`: `CODEX`, `CLAUDE`, `GEMINI`, `COPILOT`, or `none`
13. `next_actions`: Immediate follow-up steps
