# Skills for Codex

## Context Preservation (compact)

Before your session ends or when you sense context is getting large, write `artifacts/compact/codex-compact.md` capturing:
- Current task being worked on
- What step you're on
- What's been done so far
- What's left to do
- Pending decisions
- Files actively being worked on
- Any errors being debugged

This file is read by other agents to continue your work. Overwrite it each time — only the latest matters.

## Completeness Self-Check

After implementing code, scan your own output for:
- `TODO`, `FIXME`, `HACK`, `XXX`, `PLACEHOLDER`
- `console.log`, `debugger`, `print(` left behind
- Empty function bodies, hardcoded `localhost`
- Test-only values in production code
- `// removed`, `// temporary`
- Stubs or placeholder return values

If found, fix them before completing the task. Do not hand off incomplete work.

## Compliance Check

Before finishing, check your changes against:
- `coterie.md` — project collaboration rules
- `project-context.md` — does your work align with documented architecture and decisions?
- `features.md` — does your work match what's documented?

If your changes contradict documented decisions, flag the discrepancy in your cnotes.md entry rather than silently diverging.

## Evolve Context

If your work changes the project's architecture, tech stack, or key decisions, update `project-context.md`:
- Edit sections in place to reflect the current truth
- Append a changelog entry at the bottom using the changelog-as-diff format (see `references/evolve-context-diff.md`)
- Every field you change MUST have a "was → now" entry so the previous state is never lost
- The changelog is append-only — never edit or delete previous entries

## Evolve Plan

If your work completes milestones or reveals new work, update `project-plan.md`:
- Edit sections in place to reflect current state
- Append a changelog entry at the bottom using the changelog-as-diff format (see `references/evolve-plan-diff.md`)
- Every status change, addition, or removal MUST show what the previous state was
- The changelog is append-only — never edit or delete previous entries
