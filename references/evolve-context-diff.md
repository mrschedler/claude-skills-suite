# Evolve Context — Changelog-as-Diff Format

When updating `project-context.md`, edit sections in place to reflect current truth, then insert a changelog entry at the top of the changelog section (newest first) that captures exactly what changed and what it replaced.

## Changelog Entry Format

```
### YYYY-MM-DD — [PLATFORM]

- **[Section]: [Field]**: "[previous value]" → "[new value]"
- **Key Decision added**: [description] (row #N)
- **Key Decision changed**: row #N — "[old decision]" → "[new decision]"
- **Key Decision removed**: row #N — "[removed decision]" (reason: [why])
- **Reason**: [why this change was made]
```

## Rules

- Every field you change MUST have a "was → now" entry in the changelog
- If you add a new row to Key Decisions, note the row number and content
- If you change an existing row, show the old and new text
- If you remove something, record what was removed and why
- The changelog is append-only — never edit or delete previous entries
- Insert newest entries at the top of the changelog section (newest first, consistent with cnotes.md)
- One changelog entry per session/task, not per field
- `[PLATFORM]` must be one of: `CLAUDE`, `CODEX`, `GEMINI`, `COPILOT`

## Example

```
### 2026-03-06 — CODEX

- **Current State**: "MVP with REST API, no auth" → "MVP with REST API, JWT auth implemented"
- **Key Decision added**: Use RS256 JWT with rotating keys (row #12)
- **Key Decision changed**: row #8 — "Session-based auth" → "Stateless JWT auth"
- **Reason**: Session store added unacceptable complexity for multi-replica deployment
```
