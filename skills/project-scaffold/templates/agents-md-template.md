# {{PROJECT_NAME}} — Codex Instructions

Read before every task: `project-context.md`, `coterie.md`, `features.md`, `project-plan.md`.

## Rules

- Log all code writes and reviews to `cnotes.md` (structured note format per `coterie.md`)
- Scan for TODOs, stubs, debug logs, placeholder values before completing any task — fix them
- Check changes against `project-context.md` and `features.md` — flag discrepancies in `cnotes.md`
- No hardcoded secrets — use environment variables with empty-string fallbacks
- Update `project-context.md` and `project-plan.md` if your work changes architecture or completes milestones (changelog at top, newest first, identify as `CODEX`)
- Write `artifacts/compact/codex-compact.md` before session ends with current task state
