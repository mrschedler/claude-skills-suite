# Evolve Plan — Changelog-as-Diff Format

When updating `project-plan.md`, edit sections in place to reflect current state, then insert a changelog entry at the top of the changelog section (newest first) that captures exactly what changed and what it replaced.

## Changelog Entry Format

```
### YYYY-MM-DD — [PLATFORM]

- **Completed**: [work unit ID/name] — [brief outcome]
- **Added**: [work unit ID/name] — [why it was discovered/needed]
- **Changed**: [work unit ID/name] — "[old scope/status]" → "[new scope/status]"
- **Removed**: [work unit ID/name] — [why it's no longer needed]
- **Blocker added**: [work unit] depends on [other work unit] — [why]
- **Blocker resolved**: [work unit] unblocked — [what changed]
- **Reason**: [overall rationale for this set of changes]
```

## Rules

- Every status change, addition, or removal MUST appear in the changelog
- Show what the previous state was, not just the new state
- If completing a work unit reveals new work, log both the completion and the discovery
- If dependencies shift, record old and new dependency chains
- The changelog is append-only — never edit or delete previous entries
- Insert newest entries at the top of the changelog section (newest first, consistent with cnotes.md)
- One changelog entry per session/task, not per work unit
- `[PLATFORM]` must be one of: `CLAUDE`, `CODEX`, `GEMINI`, `COPILOT`

## Example

```
### 2026-03-06 — CODEX

- **Completed**: WU-3 (auth middleware) — JWT validation + role extraction working
- **Changed**: WU-5 — "blocked by WU-4" → "blocked by WU-4 and WU-8"
- **Added**: WU-8 (WebSocket auth layer) — discovered during WU-3 that WS connections need token validation too
- **Blocker added**: WU-5 depends on WU-8 — real-time features need auth before integration
- **Reason**: WU-3 implementation revealed WebSocket auth was unplanned but required
```
