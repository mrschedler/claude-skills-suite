# Coterie — Collaboration Rules

> These rules govern how all agents (CLAUDE, CODEX, GEMINI, COPILOT) collaborate in this project.

## Note Schema

When you write code, modify code, or review code, add a note to `cnotes.md`. Insert newest-first (top insertion below the `## Notes (Newest First)` header). Once a newer note exists above yours, your note is locked — do not modify it.

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

### Required Fields

Every note must include all 13 fields:

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
12. `handoff_to`: `CODEX`, `CLAUDE`, `GEMINI`, or `COPILOT`
13. `next_actions`: Immediate follow-up steps

## Communication Style

- Be direct. Lead with the answer or action, not the reasoning.
- Use bullet points over prose for plans, summaries, and deliverables.
- When referencing code, include `file_path:line_number`.

## Code Standards

- Follow existing patterns in the codebase — consistency over personal preference.
- No hardcoded secrets. Use environment variables with empty-string fallbacks.
- Clean up after yourself: no debug logs, no commented-out code, no stubs left behind.

## Commit Messages

- Format: `type: concise description` (e.g., `feat: add user auth middleware`, `fix: handle null response from API`)
- Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
- Keep the subject line under 72 characters.
